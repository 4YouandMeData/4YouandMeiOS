//
//  DeviceManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/01/21.
//

import Foundation
import RxSwift
import CoreLocation
import SystemConfiguration.CaptiveNetwork
import CryptoKit

struct DeviceData: Codable {
    let batteryLevel: Float
    let longitude: Double?
    let latitude: Double?
    let locationPermission: String
    let timezone: String
    let hashedSSID: String?
    let timestamp: Double
}

class DeviceManager: NSObject {
    
    private lazy var uploader = BatchEventUploader<DeviceData>(withConfig: Constants.Misc.DeviceDataUploadConfig,
                                                               storage: self.storage,
                                                               reachability: self.reachability)
    
    private var storage: BatchEventUploaderStorage & CacheService
    private let repository: Repository
    private let reachability: ReachabilityService & BatchEventUploaderReachability
    
    private let locationManager: CLLocationManager?
    
    private let waitingForLocationUpdate = ExpiringValue<Bool>(withDefaultValue: false, expiryTime: Constants.Misc.WaitingTimeForLocation)
    
    private let disposeBag = DisposeBag()
    
    init(repository: Repository,
         locationServicesAvailable: Bool,
         storage: BatchEventUploaderStorage & CacheService,
         reachability: ReachabilityService & BatchEventUploaderReachability) {
        self.repository = repository
        self.locationManager = locationServicesAvailable ? CLLocationManager() : nil
        self.storage = storage
        self.reachability = reachability
        super.init()
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        if let locationManager = self.locationManager {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.delegate = self
        }
        
        self.addApplicationDidBecomeActiveObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // MARK: - Actions
    
    @objc private func applicationDidBecomeActive() {
        if self.uploader.setupCompleted {
            print("DeviceManager - Add Record on Resume")
            self.addRecordData()
        } else {
            print("DeviceManager - Setup")
            self.uploader.setup(getRecord: { return nil },
                                getUploadRequest: { [weak self] buffer in
                                    guard let self = self, let deviceData = buffer.records.first else {
                                        return Single.just(())
                                    }
                                    return self.sendDeviceData(deviceData: deviceData)
                                })
            
            guard let locationManager = self.locationManager else {
                print("DeviceManager - Location Services not expected for this study. Add Startup Record")
                self.addRecordData()
                return
            }
            
            if CLLocationManager.locationServicesEnabled(), Constants.Misc.DefaultLocationPermission.isAuthorized {
                print("DeviceManager - Location Enabled. Deferred Startup record to first updated location")
                self.waitingForLocationUpdate.setValue(value: true,
                                                       onExpiry: { [weak self] in
                                                        print("DeviceManager - No location update arrived in time. Send Startup Record")
                                                        self?.addRecordData()
                                                       })
                locationManager.startUpdatingLocation()
            } else {
                print("DeviceManager - Location Disabled. Add Startup Record")
                locationManager.stopUpdatingLocation()
                self.addRecordData()
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
    
    private func sendDeviceData(deviceData: DeviceData) -> Single<()> {
        // Send data only if the user is logged in
        guard self.repository.isLoggedIn else {
            return Single.just(())
        }
        return self.repository.sendDeviceData(deviceData: deviceData)
    }
    
    private func addRecordData() {
        if self.uploader.setupCompleted, self.repository.isLoggedIn {
            let location: UserLocation? = {
                guard let locationManager = self.locationManager else {
                    return nil
                }
                
                if Constants.Misc.TrackRelativeLocation {
                    if let firstUserAbsoluteLocation = self.storage.firstUserAbsoluteLocation,
                       let currentAbsoluteLocation = locationManager.location?.coordinate.userLocation {
                        return currentAbsoluteLocation.getLocation(relativeTo: firstUserAbsoluteLocation)
                    } else {
                        return nil
                    }
                } else {
                    return locationManager.location?.coordinate.userLocation
                }
            }()
            print("DeviceManager - Add Record Data. Current Location: \(String(describing: location))")
            let deviceData = DeviceData(batteryLevel: UIDevice.current.batteryLevel,
                                        longitude: location?.longitude,
                                        latitude: location?.latitude,
                                        locationPermission: self.getLocationPermission(),
                                        timezone: TimeZone.current.identifier,
                                        hashedSSID: self.getCurrentSSID(),
                                        timestamp: Date().timeIntervalSince1970)
            
            self.uploader.addRecord(record: deviceData)
        }
    }
    
    /// Retrieve the current SSID from a connected Wifi network
    private func getCurrentSSID() -> String? {
        switch self.reachability.currentReachabilityType {
        case .wifi:
            let interfaces = CNCopySupportedInterfaces() as? [String]
            let ssid = interfaces?
                .compactMap { [weak self] in self?.getInterfaceInfo(from: $0) }
                .first
            print("DeviceManager - Current Plain SSID: \(String(describing: ssid))")
            return ssid?.sha512Hex
        case .cellular: return "no-wifi"
        case .none: return nil
        }
    }
    
    /// Retrieve information about a specific network interface
    private func getInterfaceInfo(from interface: String) -> String? {
        guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: AnyObject],
            let ssid = interfaceInfo[kCNNetworkInfoKeySSID as String] as? String
            else {
                return nil
        }
        return ssid
    }
    
    private func getLocationPermission() -> String {
        if Constants.Misc.DefaultLocationPermission.isAuthorized {
            return "granted"
        } else if Constants.Misc.DefaultLocationPermission.isDenied {
            return "denied"
        } else if Constants.Misc.DefaultLocationPermission.isRestricted {
            return "restricted"
        } else {
            return "undetermined"
        }
    }
}

// MARK: - DeviceService

extension DeviceManager: DeviceService {
    
    var locationServicesAvailable: Bool { return self.locationManager != nil }
    
    func onLocationPermissionChanged() {
        guard let locationManager = self.locationManager else {
            return
        }
        
        if Constants.Misc.DefaultLocationPermission.isAuthorized {
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
        }
    }
}

extension DeviceManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("DeviceManager - Location Update - No last location")
            return
        }
        
        let updateDate = location.timestamp
        let referenceDate = Date(timeIntervalSinceNow: -Constants.Misc.MaxValidLocationAge)
        guard updateDate > referenceDate else {
            let updateAge = updateDate.timeIntervalSince1970 - Date().timeIntervalSince1970
            print("DeviceManager - Location Update - Value too old (\(updateAge) seconds old). Ignore")
            return
        }
        
        if self.storage.firstUserAbsoluteLocation == nil, Constants.Misc.TrackRelativeLocation {
            let userLocation = location.coordinate.userLocation
            print("DeviceManager - Stored first user absolute location: (lat: \(userLocation.latitude), lon: \(userLocation.longitude))")
            self.storage.firstUserAbsoluteLocation = userLocation
        }
        
        if self.waitingForLocationUpdate.value {
            self.waitingForLocationUpdate.resetValue()
            print("DeviceManager - Location Update Success. Add Deferred Startup Record")
            self.addRecordData()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("DeviceManager - Location Update Failed. Error: '\(error)'")
        
        if self.waitingForLocationUpdate.value {
            self.waitingForLocationUpdate.resetValue()
            print("DeviceManager - Location Update Failed. Add Deferred Startup Record")
            self.addRecordData()
        }
    }
}

fileprivate extension String {
    var sha512Hex: String {
        let inputData = Data(self.utf8)
        let hashedData = SHA512.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension UserLocation {
    var nativeLocation: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
    func getLocation(relativeTo referenceLocation: UserLocation) -> UserLocation {
        return UserLocation(latitude: self.latitude - referenceLocation.latitude,
                            longitude: self.longitude - referenceLocation.longitude)
    }
}

extension CLLocationCoordinate2D {
    var userLocation: UserLocation {
        return UserLocation(latitude: self.latitude, longitude: self.longitude)
    }
}
