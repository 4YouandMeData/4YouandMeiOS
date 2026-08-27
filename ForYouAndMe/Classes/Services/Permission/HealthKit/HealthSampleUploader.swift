//
//  HealthSampleUploader.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/06/21.
//

import Foundation
import RxSwift

protocol HealthSampleUploaderNetworkDelegate: AnyObject {
    func uploadHealthNetworkData(_ healthNetworkData: HealthNetworkData, source: String) -> Single<()>
}

protocol HealthSampleUploaderStorage {
    func saveLastSampleUploadAnchor<T: NSSecureCoding>(_ anchor: T?, forDataType dateType: HealthDataType)
    func loadLastSampleUploadAnchor<T: NSSecureCoding & NSObject>(forDataType dateType: HealthDataType) -> T?
}

enum HealthSampleUploaderError: Error {
    case internalError
    case unexpectedDataType
    case fetchDataError(underlyingError: Error)
    case uploadServerError(underlyingError: Error)
    case uploadConnectivityError
    /// FUAM-3945: the chunk's payload is over the server's request cap (pre-flight estimate, or
    /// an HTTP 413). The caller must halve the chunk's TIME window and retry, never retry as is.
    case uploadPayloadTooLarge
}

#if HEALTHKIT
import HealthKit

private struct HealthQueryResult {
    let anchor: HKQueryAnchor?
    let samples: [HKSample]
}

class HealthSampleUploader {
    public weak var networkDelegate: HealthSampleUploaderNetworkDelegate?
    
    let sampleDataType: HealthDataType
    
    private var storage: HealthSampleUploaderStorage
    
    private let healthStore = HKHealthStore()
    
    init(withSampleDataType sampleDataType: HealthDataType, storage: HealthSampleUploaderStorage) {
        self.storage = storage
        self.sampleDataType = sampleDataType
    }
    
    /// `useAnchoredQuery: false` runs a plain `HKSampleQuery` for the chunk instead of the
    /// anchored query (FUAM-3841 review fix #8): during the historical backfill walk an
    /// anchored query can skip samples inserted out of order, and its anchor must not be
    /// advanced past data the incremental head hasn't reached yet. Apple's guidance:
    /// sample queries for history, anchored queries for incremental sync.
    ///
    /// `minimumSampleDate` is the hard consent gate (`BackfillLowerBound`) and is deliberately
    /// NOT optional and NOT defaulted (FUAM-3945 review fix #6): a consent gate must never be
    /// opt-in, and the previous `nil` default meant "skip filtering entirely".
    public func run(startDate: Date,
                    endDate: Date,
                    source: String,
                    minimumSampleDate: Date,
                    useAnchoredQuery: Bool = true) -> Single<()> {
        guard let networkDelegate = self.networkDelegate else {
            assertionFailure("Missing Network Delegate")
            return Single.error(HealthSampleUploaderError.internalError)
        }

        guard let sampleType = self.sampleDataType.sampleType else {
            assertionFailure("Current HealthDataType is not a sample type")
            return Single.error(HealthSampleUploaderError.unexpectedDataType)
        }

        return Single<HealthQueryResult>.create { observer in
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

            let query: HKQuery
            if useAnchoredQuery {
                let anchor: HKQueryAnchor? = self.storage.loadLastSampleUploadAnchor(forDataType: self.sampleDataType)
                query = HKAnchoredObjectQuery(type: sampleType,
                                              predicate: datePredicate,
                                              anchor: anchor,
                                              limit: HKObjectQueryNoLimit) { _, samplesOrNil, _, newAnchor, errorOrNil in
                    if let error = errorOrNil {
                        observer(.failure(HealthSampleUploaderError.fetchDataError(underlyingError: error)))
                    } else {
                        observer(.success(HealthQueryResult(anchor: newAnchor, samples: samplesOrNil ?? [])))
                    }
                }
            } else {
                let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
                query = HKSampleQuery(sampleType: sampleType,
                                      predicate: datePredicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sortByStartDate]) { _, samplesOrNil, errorOrNil in
                    if let error = errorOrNil {
                        observer(.failure(HealthSampleUploaderError.fetchDataError(underlyingError: error)))
                    } else {
                        // anchor nil: the historical walk never touches the stored anchor.
                        observer(.success(HealthQueryResult(anchor: nil, samples: samplesOrNil ?? [])))
                    }
                }
            }

            self.healthStore.execute(query)
            return Disposables.create()
        }
        .flatMap { result -> Single<HKQueryAnchor?> in
            let samples = Self.consentFiltered(result.samples, minimum: minimumSampleDate)
            self.logDebugText(text: "Uploading \(samples.count) samples from \(startDate) to \(endDate)")

            guard samples.count > 0 else {
                return Single.just(result.anchor)
            }

            let networkData = samples.getNetworkData(forDataType: self.sampleDataType)

            // FUAM-3945: pre-flight size gate. The server rejects a request above
            // `MAX_PAYLOAD_SIZE` (10 MB) and the chunk walk cannot advance past a rejected
            // chunk, so one dense day of a high-frequency type (watch heart rate) used to stall
            // the whole data type for ever. Refusing to send here turns that into a
            // deterministic time bisection in `HealthSampleUploadManager`.
            if let payloadBytes = Self.serializedSize(of: networkData),
               payloadBytes > Constants.HealthKit.MaxUploadPayloadBytes {
                self.logDebugText(text: "Payload of \(payloadBytes) bytes from \(startDate) to \(endDate) "
                                  + "is over the \(Constants.HealthKit.MaxUploadPayloadBytes) byte threshold")
                return Single.error(HealthSampleUploaderError.uploadPayloadTooLarge)
            }

            return networkDelegate.uploadHealthNetworkData(networkData, source: source)
                .map { result.anchor }
        }
        .do(onSuccess: { anchor in
            if let anchor = anchor {
                self.storage.saveLastSampleUploadAnchor(anchor, forDataType: self.sampleDataType)
            }
        })
        .toVoid()
    }

    /// The hard consent gate: drop any sample measured before the backfill lower bound (the study
    /// join day / 365-day cap — see `BackfillLowerBound`), regardless of what the query returned.
    /// Client-side, does not depend on the server.
    ///
    /// `>=`, not `>`: the bound is the START of the join day, so a sample stamped exactly at
    /// midnight was measured on the join day and is consented. Extracted from the query pipeline
    /// (FUAM-3945, F6) purely so it can be executed by a test — the `uploadChunk` seam the chunk
    /// specs use bypasses this whole uploader, which left the only per-sample consent gate in the
    /// HealthKit path unexercised.
    static func consentFiltered(_ samples: [HKSample], minimum: Date) -> [HKSample] {
        return samples.filter { $0.startDate >= minimum }
    }

    /// Serialized JSON size of an upload payload — the request body is this dictionary inside a
    /// small `integration_data` envelope, so it is a faithful measure. `nil` when the payload
    /// cannot be serialized at all, in which case the upload is attempted anyway: a rejected
    /// request is recoverable, a chunk skipped on a guess is not.
    // ponytail: serializes the payload once more than strictly needed (Alamofire encodes it
    // again) — acceptable against a silent per-type stall; revisit only if profiling complains.
    static func serializedSize(of networkData: HealthNetworkData) -> Int? {
        guard JSONSerialization.isValidJSONObject(networkData),
              let data = try? JSONSerialization.data(withJSONObject: networkData) else { return nil }
        return data.count
    }

    private func logDebugText(text: String) {
        #if DEBUG
        if Constants.HealthKit.EnableDebugLog {
            print("HealthSampleUploader.\(self.sampleDataType.keyName) - \(text)")
        }
        #endif
    }
}

#endif
