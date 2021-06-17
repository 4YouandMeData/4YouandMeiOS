//
//  HealthManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
import RxSwift
#if HEALTHKIT
import HealthKit

class HealthManager: HealthService {
    
    private let readTypes: [HealthReadType]
    
    init(withReadTypes readTypes: [HealthReadType]) {
        // If read types are not provided, HealthKit should be removed
        assert(readTypes.count > 0, "Read Types are not provided but the HEALTHKIT compilation condition has been defined")
        self.readTypes = readTypes
    }
    
//    private static let defaultMeasurements: Set<HKSampleType> = [
//        HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!,
//        HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
//        HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
//    ]
//    
//    private let healthStore = HKHealthStore()
//    
//    // MARK: - HealthService
//    
//    public func requestPermissionDefaultMeasurements() -> Single<()> {
//        return self.requestPermission(measurements: Self.defaultMeasurements)
//    }
//    
//    public func requestPermission(measurements: Set<HKSampleType>) -> Single<()> {
//        guard HKHealthStore.isHealthDataAvailable() else {
//            return Single.error(HealthError.healthKitNotAvailable)
//        }
//        
//        return Single.create { singleEvent -> Disposable in
//            //Background Thread
//            self.healthStore.requestAuthorization(toShare: measurements, read: nil, completion: { (success, error) in
//                
//                //Main Thread
//                DispatchQueue.main.async {
//                    if success {
//                        singleEvent(.success(()))
//                    } else {
//                        print("HealthManager - Permission Request failed. Error: \(String(describing: error?.localizedDescription))")
//                        singleEvent(.error(HealthError.permissionRequestError))
//                    }
//                }
//            })
//            return Disposables.create()
//        }
//    }
}

#else

class HealthManager: HealthService {
    
    init(withReadTypes readTypes: [HealthReadType]) {
        // If read types are provided, you probabily want to add HealthKit.
        assert(readTypes.count == 0, "Read Types are provided but the HEALTHKIT compilation condition has not been defined")
    }
}

#endif
