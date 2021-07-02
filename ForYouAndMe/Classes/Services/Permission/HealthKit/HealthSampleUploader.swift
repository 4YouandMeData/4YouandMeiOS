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
    var lastUploadSequenceCompletionDate: Date? { get set }
    func saveLastSampleUploadAnchor<T: NSSecureCoding & NSObject>(_ anchor: T?, forDataType dateType: HealthDataType)
    func loadLastSampleUploadAnchor<T: NSSecureCoding & NSObject>(forDataType dateType: HealthDataType) -> T?
}

#if HEALTHKIT
import HealthKit

enum HealthSampleUploaderError: Error {
    case internalError
    case unexpectedDataType
    case fetchDataError(underlyingError: Error)
    case uploadServerError(underlyingError: Error)
    case uploadConnectivityError
    case readPermissionDenied
}

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
        
        guard self.healthStore.authorizationStatus(for: sampleType) == .sharingAuthorized else {
            print("HealthSampleUploader - User didn't granted permission to read '\(self.sampleDataType)' data type")
            return Single.error(HealthSampleUploaderError.readPermissionDenied)
        }
        
        let startDate =  self.storage.lastUploadSequenceCompletionDate
            ?? Date(timeIntervalSinceNow: -Constants.HealthKit.SamplesStartDateTimeInThePast)
        let endDate =  Date()
        
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
            guard result.samples.count > 0 else { return Single.just(result.anchor) }
            return networkDelegate.uploadHealthNetworkData(result.samples.getNetworkData(forDataType: self.sampleDataType))
                .map { result.anchor }
        }
        .do(onSuccess: { anchor in
            assert(anchor != nil, "Missing anchor!!! The anchor is necessary to avoid sending duplicates to the server.")
            self.storage.saveLastSampleUploadAnchor(anchor, forDataType: self.sampleDataType)
            if self.storage.lastUploadSequenceCompletionDate == nil {
                self.storage.lastUploadSequenceCompletionDate = startDate
            }
        })
        .toVoid()
    }
}

#endif
