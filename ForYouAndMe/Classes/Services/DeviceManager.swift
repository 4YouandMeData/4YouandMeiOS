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
    
    private lazy var uploader = BatchEventUploader<DeviceData>(withConfig: Constants.Misc.deviceDataUploadConfig,
                                                               storage: self.storage,
                                                               reachability: self.reachability)
    
    private var waitingForLocationUpdate: Bool = false
    
    private let locationManager = CLLocationManager()
    
    private let repository: Repository
    private var storage: BatchEventUploaderStorage
    private let reachability: ReachabilityService & BatchEventUploaderReachability
    
    private let disposeBag = DisposeBag()
    
    init(repository: Repository,
         storage: BatchEventUploaderStorage,
         reachability: ReachabilityService & BatchEventUploaderReachability) {
        self.repository = repository
        self.storage = storage
        self.reachability = reachability
        super.init()
        
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.delegate = self
        
        self.addApplicationDidBecomeActiveObserver()
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
            
            if CLLocationManager.locationServicesEnabled(), Constants.Misc.defaultLocationPermission.isAuthorized {
                print("DeviceManager - Location Enabled. Deferred Startup record to first updated location")
                self.waitingForLocationUpdate = true
                self.locationManager.startUpdatingLocation()
            } else {
                print("DeviceManager - Location Disabled. Add Startup Record")
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
            
            let location = self.locationManager.location
            print("DeviceManager - Add Record Data .Current Location: \(String(describing: location?.coordinate))")
            let deviceData = DeviceData(batteryLevel: UIDevice.current.batteryLevel,
                                        longitude: location?.coordinate.longitude,
                                        latitude: location?.coordinate.latitude,
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
        if Constants.Misc.defaultLocationPermission.isAuthorized {
            return "granted"
        } else if Constants.Misc.defaultLocationPermission.isDenied {
            return "denied"
        } else if Constants.Misc.defaultLocationPermission.isRestricted {
            return "restricted"
        } else {
            return "undetermined"
        }
    }
}

// MARK: - DeviceService

extension DeviceManager: DeviceService {
    func onLocationPermissionChanged() {
        if Constants.Misc.defaultLocationPermission.isAuthorized {
            self.locationManager.stopUpdatingLocation()
            self.locationManager.startUpdatingLocation()
        } else {
            self.locationManager.stopUpdatingLocation()
        }
    }
}

extension DeviceManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if self.waitingForLocationUpdate {
            self.waitingForLocationUpdate = false
            print("DeviceManager - Location Update Success. Add Deferred Startup Record")
            self.addRecordData()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("DeviceManager - Location Update Failed. Error: '\(error)'")
        
        if self.waitingForLocationUpdate {
            self.waitingForLocationUpdate = false
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
