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

class HealthSampleUploader {
    public weak var networkDelegate: HealthSampleUploaderNetworkDelegate?

    /// For the `proactive_split` breadcrumb (AC5/AC8). Set by `HealthSampleUploadManager`.
    var analytics: AnalyticsService?

    let sampleDataType: HealthDataType

    private var storage: HealthSampleUploaderStorage

    private let healthStore = HKHealthStore()

    init(withSampleDataType sampleDataType: HealthDataType, storage: HealthSampleUploaderStorage) {
        self.storage = storage
        self.sampleDataType = sampleDataType
    }

    /// Fetches one time chunk with a plain `HKSampleQuery` and uploads it.
    ///
    /// FUAM-3945 round 9 (C1 item 7, fixes H3): the anchored-query path is REMOVED, not
    /// parameterised away — an `HKAnchoredObjectQuery` behind a date predicate captures anchors
    /// that silently skip out-of-order inserts, and the walk is a pure historical reader. The
    /// stored anchors are left untouched and unused; the change-feed redesign (T-A) starts from
    /// this clean state with a NEW anchor namespace.
    ///
    /// The predicate uses `.strictStartDate` (fixes H4): chunks share their boundary instant, so
    /// the default overlap semantics returned a boundary-straddling sample from BOTH adjacent
    /// chunks, duplicating it server-side under two anchors.
    ///
    /// `minimumSampleDate` is the hard consent gate (`BackfillLowerBound`) and is deliberately
    /// NOT optional and NOT defaulted (FUAM-3945 review fix #6): a consent gate must never be
    /// opt-in, and the previous `nil` default meant "skip filtering entirely".
    public func run(startDate: Date,
                    endDate: Date,
                    source: String,
                    minimumSampleDate: Date) -> Single<()> {
        guard let networkDelegate = self.networkDelegate else {
            assertionFailure("Missing Network Delegate")
            return Single.error(HealthSampleUploaderError.internalError)
        }

        guard let sampleType = self.sampleDataType.sampleType else {
            assertionFailure("Current HealthDataType is not a sample type")
            return Single.error(HealthSampleUploaderError.unexpectedDataType)
        }

        return Single<[HKSample]>.create { observer in
            let sortByStartDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: sampleType,
                                      predicate: Self.chunkPredicate(startDate: startDate, endDate: endDate),
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [sortByStartDate]) { _, samplesOrNil, errorOrNil in
                if let error = errorOrNil {
                    observer(.failure(HealthSampleUploaderError.fetchDataError(underlyingError: error)))
                } else {
                    observer(.success(samplesOrNil ?? []))
                }
            }

            self.healthStore.execute(query)
            return Disposables.create()
        }
        .flatMap { fetched -> Single<()> in
            // AC2: a deterministic total order (startDate, then uuid) so the same sample set
            // always partitions into the same chunks — the sort descriptor alone leaves
            // same-startDate ties in store order, which a reinstall does not reproduce.
            let samples = Self.deterministicallyOrdered(Self.consentFiltered(fetched, minimum: minimumSampleDate))
            self.logDebugText(text: "Uploading \(samples.count) samples from \(startDate) to \(endDate)")

            guard samples.count > 0 else {
                return Single.just(())
            }

            // AC5: never EXCEED the server's 10 MB request cap — size the payload as the batch
            // is built and split PROACTIVELY at the 8 MB margin. The manager's reactive time
            // bisection survives only as the backstop, reached when even a single sample is
            // over the margin (a hard, reported condition — never a silent drop).
            guard let chunks = Self.proactiveChunks(of: samples,
                                                    forDataType: self.sampleDataType,
                                                    marginBytes: Constants.HealthKit.MaxUploadPayloadBytes) else {
                self.logDebugText(text: "A single sample from \(startDate) to \(endDate) exceeds the payload margin")
                return Single.error(HealthSampleUploaderError.uploadPayloadTooLarge)
            }
            if chunks.count > 1 {
                self.analytics?.track(event: .sensorDataBackfillReach(
                    sensor: "health_kit_" + self.sampleDataType.keyName,
                    reachedBack: ISO8601DateFormatter().string(from: startDate),
                    boundedBy: BackfillLowerBound.Origin.proactiveSplit.rawValue))
            }
            // Sequential, in order: a failure mid-sequence re-runs the whole time chunk on a
            // later sequence, and the already-uploaded halves merge server-side for free
            // (identical bytes, identical anchors).
            return chunks.reduce(Single.just(())) { chain, chunk in
                let payload = chunk.getNetworkData(forDataType: self.sampleDataType)
                return chain.flatMap { networkDelegate.uploadHealthNetworkData(payload, source: source) }
            }
        }
    }

    /// The chunk predicate: `[start, end)` on the sample's START date, strictly (H4). Internal
    /// seam so the strictness is pinned by a test — the walk owns no other predicate.
    static func chunkPredicate(startDate: Date, endDate: Date) -> NSPredicate {
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
    }

    /// Total order: startDate ascending, `uuid` as the tiebreak (AC2 — store order is not
    /// reproducible across reinstall; this is).
    static func deterministicallyOrdered(_ samples: [HKSample]) -> [HKSample] {
        return samples.sorted {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.uuid.uuidString < $1.uuid.uuidString
        }
    }

    /// Splits an ordered sample array into contiguous chunks whose serialized payloads all fit
    /// the margin, by recursive halving on COUNT — deterministic for the same ordered input
    /// (AC2/AC5). `nil` when a single sample exceeds the margin on its own: the caller must
    /// report, never silently drop. A chunk whose size cannot be estimated is attempted whole
    /// (a rejected request is recoverable; a chunk skipped on a guess is not).
    static func proactiveChunks(of samples: [HKSample],
                                forDataType dataType: HealthDataType,
                                marginBytes: Int) -> [[HKSample]]? {
        var chunks: [[HKSample]] = []
        func split(_ chunk: [HKSample]) -> Bool {
            guard let bytes = Self.serializedSize(of: chunk.getNetworkData(forDataType: dataType)),
                  bytes > marginBytes else {
                chunks.append(chunk)
                return true
            }
            guard chunk.count > 1 else { return false }
            let half = chunk.count / 2
            return split(Array(chunk[..<half])) && split(Array(chunk[half...]))
        }
        return split(samples) ? chunks : nil
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
