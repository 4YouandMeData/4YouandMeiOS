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
    private let reachability: BatchEventUploaderReachability
    
    private let disposeBag = DisposeBag()
    
    init(repository: Repository,
         storage: BatchEventUploaderStorage,
         reachability: BatchEventUploaderReachability) {
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
            
            if CLLocationManager.locationServicesEnabled(), getLocationAuthorized() {
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
            let deviceData = DeviceData(batteryLevel: UIDevice.current.batteryLevel,
                                        longitude: location?.coordinate.longitude,
                                        latitude: location?.coordinate.latitude,
                                        timezone: TimeZone.current.identifier,
                                        hashedSSID: self.getCurrentSSID()?.sha512Hex,
                                        timestamp: Date().timeIntervalSince1970)
            
            self.uploader.addRecord(record: deviceData)
        }
    }
    
    /// Retrieve the current SSID from a connected Wifi network
    private func getCurrentSSID() -> String? {
        let interfaces = CNCopySupportedInterfaces() as? [String]
        let ssid = interfaces?
            .compactMap { [weak self] in self?.getInterfaceInfo(from: $0) }
            .first
        print("DeviceManager - Current Plain SSID: \(String(describing: ssid))")
        return ssid
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
}

// MARK: - DeviceService

extension DeviceManager: DeviceService {
    func onLocationPermissionGranted() {
        self.locationManager.startUpdatingLocation()
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

extension String {
    var sha512Hex: String {
        let inputData = Data(self.utf8)
        let hashedData = SHA512.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
