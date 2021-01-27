//
//  HealthManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
// import HealthKit
import RxSwift

class HealthManager: HealthService {
    
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
