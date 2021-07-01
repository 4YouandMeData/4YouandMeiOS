//
//  HealthManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
import RxSwift

typealias HealthNetworkData = [String: Any]

protocol HealthManagerNetworkDelegate: HealthSampleUploaderNetworkDelegate {
    func uploadHealthNetworkData(_ healthNetworkData: HealthNetworkData) -> Single<()>
}

typealias HealthManagerStorage = HealthSampleUploadManagerStorage
typealias HealthManagerReachability = HealthSampleUploadManagerReachability

#if HEALTHKIT
import HealthKit

class HealthManager: HealthService {
    
    // InitializableService
    var isInitialized: Bool = false
    
    public weak var networkDelegate: HealthManagerNetworkDelegate? {
        didSet {
            if let networkDelegate = self.networkDelegate {
                self.healthSampleUploadManager.setNetworkDelegate(networkDelegate)
            }
        }
    }
    
    private let readDataTypes: [HealthDataType]
    private let analyticsService: AnalyticsService
    private let healthStore = HKHealthStore()
    
    private let healthSampleUploadManager: HealthSampleUploadManager
    
    private let disposeBag = DisposeBag()
    
    init(withReadDataTypes readDataTypes: [HealthDataType],
         analyticsService: AnalyticsService,
         storage: HealthManagerStorage,
         reachability: HealthManagerReachability) {
        // If read data types are not provided, HealthKit should be removed
        assert(readDataTypes.count > 0, "Read Data Types are not provided but the HEALTHKIT compilation condition has been defined")
        self.readDataTypes = readDataTypes
        self.analyticsService = analyticsService
        self.healthSampleUploadManager = HealthSampleUploadManager(withDataTypes: readDataTypes,
                                                                   storage: storage,
                                                                   reachability: reachability)
        self.addApplicationDidBecomeActiveObserver()
    }
    
    // MARK: - HealthService
    
    var serviceAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    
    func requestPermissions() -> Single<()> {
        return self.checkHealthKitAvailability()
            .flatMap {
                return Single.create { singleEvent -> Disposable in
                    // Background Thread
                    self.healthStore
                        .requestAuthorization(toShare: nil, read: self.readDataTypes.objectTypeSet, completion: { (success, error) in
                        // Main Thread
                        DispatchQueue.main.async {
                            if success {
                                self.processCharacteristicTypes()
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
                    let readDataObjectTypeSet = self.readDataTypes.objectTypeSet
                    self.healthStore
                        .getRequestStatusForAuthorization(toShare: Set(), read: readDataObjectTypeSet, completion: { (status, error) in
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
    
    private func addApplicationDidBecomeActiveObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
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
    
    private func processCharacteristicTypes() {
        guard let networkDelegate = self.networkDelegate else {
            assertionFailure("Missing Network Delegate")
            return
        }
        let data: [String: String] = self.readDataTypes.reduce([:]) { result, type in
            if let key = type.characteristicTypeKey {
                var result = result
                result[key] = type.characteristicValueDataString(healthStore: self.healthStore) ?? ""
                return result
            } else {
                return result
            }
        }
        networkDelegate.uploadHealthNetworkData(data)
            .do(onSuccess: { _ in print("HealthManager - Characteristics Data sent successfully") },
                onError: { error in print("HealthManager - Characteristics Data sending failed with error: \(error)") })
            .subscribe()
            .disposed(by: self.disposeBag)
    }
    
    // MARK: - Actions
    
    @objc private func applicationDidBecomeActive() {
        self.processCharacteristicTypes()
    }
}

// MARK: - InitializableService

extension HealthManager: InitializableService {
    func initialize() -> Single<()> {
        self.isInitialized = true
        // Need to start uploading once all dependencies are set and running (see network delegates)
        self.healthSampleUploadManager.startUploadLogic()
        return Single.just(())
    }
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
    
    init(withReadDataTypes readDataTypes: [HealthDataType], analyticsService: AnalyticsService, storage: HealthManagerStorage) {
        // If read data types are provided, you probabily want to add HealthKit.
        assert(readDataTypes.count == 0, "Read Data Types are provided but the HEALTHKIT compilation condition has not been defined")
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
