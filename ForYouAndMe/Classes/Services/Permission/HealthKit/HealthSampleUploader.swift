//
//  HealthSampleUploader.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/06/21.
//

import Foundation
import RxSwift

protocol HealthSampleUploaderNetworkDelegate: AnyObject {
    func uploadHealthNetworkData(_ healthNetworkData: HealthNetworkData) -> Single<()>
}

protocol HealthSampleUploaderStorage {
    var firstSuccessfulSampleUploadDate: Date? { get set }
    func saveLastSampleUploadAnchor<T: NSSecureCoding>(_ anchor: T?, forDataType dateType: HealthDataType)
    func loadLastSampleUploadAnchor<T: NSSecureCoding & NSObject>(forDataType dateType: HealthDataType) -> T?
}

enum HealthSampleUploaderError: Error {
    case internalError
    case unexpectedDataType
    case fetchDataError(underlyingError: Error)
    case uploadServerError(underlyingError: Error)
    case uploadConnectivityError
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
    
    public func run() -> Single<()> {
        guard let networkDelegate = self.networkDelegate else {
            assertionFailure("Missing Network Delegate")
            return Single.error(HealthSampleUploaderError.internalError)
        }
        
        guard let sampleType = self.sampleDataType.sampleType else {
            assertionFailure("Current HealthDataType is not a sample type")
            return Single.error(HealthSampleUploaderError.unexpectedDataType)
        }
        
        let startDate = self.storage.firstSuccessfulSampleUploadDate
            ?? Date(timeIntervalSinceNow: -Constants.HealthKit.SamplesStartDateTimeInThePast)
        let endDate = Date()
        
        return Single<HealthQueryResult>.create { singleEvent in
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
            let anchor: HKQueryAnchor? = self.storage.loadLastSampleUploadAnchor(forDataType: self.sampleDataType)
            let query = HKAnchoredObjectQuery(type: sampleType,
                                              predicate: datePredicate,
                                              anchor: anchor,
                                              limit: HKObjectQueryNoLimit,
                                              resultsHandler: { (_, samplesOrNil, _, newAnchor, errorOrNil) in
                                                if let error = errorOrNil {
                                                    singleEvent(.error(HealthSampleUploaderError.fetchDataError(underlyingError: error)))
                                                } else {
                                                    singleEvent(.success(HealthQueryResult(anchor: newAnchor, samples: samplesOrNil ?? [])))
                                                }
                                              })
            self.healthStore.execute(query)
            return Disposables.create()
        }.flatMap { result -> Single<HKQueryAnchor?> in
            self.logDebugText(text: "\(result.samples.count) to upload")
            guard result.samples.count > 0 else {
                return Single.just(result.anchor)
            }
            return networkDelegate.uploadHealthNetworkData(result.samples.getNetworkData(forDataType: self.sampleDataType))
                .map { result.anchor }
        }
        .do(onSuccess: { anchor in
            if let anchor = anchor {
                self.storage.saveLastSampleUploadAnchor(anchor, forDataType: self.sampleDataType)
            }
            if self.storage.firstSuccessfulSampleUploadDate == nil {
                self.storage.firstSuccessfulSampleUploadDate = startDate
            }
        })
        .toVoid()
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
