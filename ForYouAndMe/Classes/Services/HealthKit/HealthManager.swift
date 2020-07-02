//
//  HealthManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
import HealthKit
import RxSwift

class HealthManager: HealthService {
    
    private let healthStore = HKHealthStore()
    
    // MARK: - HealthService
    
    public func requestPermission() -> Single<()> {
        guard HKHealthStore.isHealthDataAvailable() else {
            return Single.error(HealthError.healthKitNotAvailable)
        }
        
        // TODO: Get these dynamically
        let measuraments: Set = [HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!,
                                 HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
                                 HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!]
        
        return Single.create { singleEvent -> Disposable in
            //Background Thread
            self.healthStore.requestAuthorization(toShare: measuraments, read: nil, completion: { (success, error) in
                
                //Main Thread
                DispatchQueue.main.async {
                    if success {
                        singleEvent(.success(()))
                    } else {
                        print("HealthManager - Permission Request failed. Error: \(String(describing: error?.localizedDescription))")
                        singleEvent(.error(HealthError.permissionRequestError))
                    }
                }
            })
            return Disposables.create()
        }
    }
}
