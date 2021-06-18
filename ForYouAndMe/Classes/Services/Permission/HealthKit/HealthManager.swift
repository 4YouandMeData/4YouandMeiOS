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
    private let analyticsService: AnalyticsService
    private let healthStore = HKHealthStore()
    
    init(withReadTypes readTypes: [HealthReadType], analyticsService: AnalyticsService) {
        // If read types are not provided, HealthKit should be removed
        assert(readTypes.count > 0, "Read Types are not provided but the HEALTHKIT compilation condition has been defined")
        self.readTypes = readTypes
        self.analyticsService = analyticsService
    }
    
    // MARK: - HealthService
    
    var serviceAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    
    func requestPermissions() -> Single<()> {
        return self.checkHealthKitAvailability()
            .flatMap {
                return Single.create { singleEvent -> Disposable in
                    // Background Thread
                    self.healthStore
                        .requestAuthorization(toShare: nil, read: self.readTypes.objectTypeSet, completion: { (success, error) in
                        // Main Thread
                        DispatchQueue.main.async {
                            if success {
                                singleEvent(.success(()))
                            } else {
                                // Apple doc don't specify what could cause this error. Check if and when they occur.
                                assertionFailure("Permission request error. Error \(String(describing: error?.localizedDescription))")
                                let healthError = HealthError.permissionRequestError(underlyingError: error)
                                self.analyticsService.track(event: .healthError(healthError: healthError))
                                singleEvent(.error(healthError))
                            }
                        }
                    })
                    return Disposables.create()
                }
            }
    }
    
    func getIsAuthorizationStatusUndetermined() -> Single<Bool> {
        return self.checkHealthKitAvailability()
            .flatMap {
                return Single.create { singleEvent -> Disposable in
                    // Background Thread
                    let readObjectTypeSet = self.readTypes.objectTypeSet
                    self.healthStore
                        .getRequestStatusForAuthorization(toShare: Set(), read: readObjectTypeSet, completion: { (status, error) in
                            // Main Thread
                            DispatchQueue.main.async {
                                if let error = error {
                                    // Apple doc don't specify what could cause this error. Check if and when they occur.
                                    assertionFailure("Get Request Authorization Status error. Error \(error.localizedDescription)")
                                    let healthError = HealthError.getPermissionRequestStatusError(underlyingError: error)
                                    self.analyticsService.track(event: .healthError(healthError: healthError))
                                    singleEvent(.error(healthError))
                                } else {
                                    singleEvent(.success(status.isPermissionsUndetermined))
                                }
                            }
                        })
                    return Disposables.create()
                }
            }
    }
    
    // MARK: - Private Methods
    
    private func checkHealthKitAvailability() -> Single<()> {
        guard HKHealthStore.isHealthDataAvailable() else {
            // TODO: Handle this in more user-friendly way.
            // This should fail only on iPad, which we don't currently support, but one day we could.
            assertionFailure("HealthKit not available on current device")
            let healthError = HealthError.healthKitNotAvailable
            self.analyticsService.track(event: .healthError(healthError: healthError))
            return Single.error(healthError)
        }
        return Single.just(())
    }
}

// MARK: - HealthReadType Extensions

extension HealthReadType {
    var objectType: HKObjectType {
        switch self {
        case .bloodType: return HKObjectType.characteristicType(forIdentifier: .bloodType)!
        case .stepCount: return HKObjectType.quantityType(forIdentifier: .stepCount)!
        }
    }
}

extension Array where Element == HealthReadType {
    var objectTypeSet: Set<HKObjectType> { self.map { $0.objectType }.toSet }
}

// MARK: - HKAuthorizationRequestStatus Extensions

extension HKAuthorizationRequestStatus {
    var isPermissionsUndetermined: Bool {
        switch self {
        case .shouldRequest, .unknown: return true
        case .unnecessary: return false
        @unknown default:
            assertionFailure("New unhandled case")
            return false
        }
    }
}

#else

// MARK: - Dummy HealthManager

class HealthManager: HealthService {
    
    init(withReadTypes readTypes: [HealthReadType], analyticsService: AnalyticsService) {
        // If read types are provided, you probabily want to add HealthKit.
        assert(readTypes.count == 0, "Read Types are provided but the HEALTHKIT compilation condition has not been defined")
    }
    
    // MARK: - HealthService
    
    var serviceAvailable: Bool { false }
    
    func getIsAuthorizationStatusUndetermined() -> Single<Bool> {
        assertionFailure("Unexpected get authorization status. The HEALTHKIT compilation condition has not been defined")
        return false
    }
    
    func requestPermission() -> Single<()> {
        assertionFailure("Unexpected health permission request. The HEALTHKIT compilation condition has not been defined")
        return Single<()>
    }
}

#endif
