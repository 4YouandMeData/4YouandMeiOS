//
//  SensorKitPermission.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 24/07/25.
//

import SensorKit

struct SensorKitPermission: PermissionProtocol {
    
    private let sensorManager = SRSensorReader(sensor: .accelerometer)
    
    var isAuthorized: Bool {
        return sensorManager.authorizationStatus == .authorized
    }
    
    var isDenied: Bool {
        return sensorManager.authorizationStatus == .denied
    }
    
    var isNotDetermined: Bool {
        return sensorManager.authorizationStatus == .notDetermined
    }
    
    var isRestricted: Bool {
        return false
    }
    
    func request(completion: @escaping () -> Void?) {
        do {
            SRSensorReader.requestAuthorization(sensors: [.accelerometer]) { error in
                if let error = error {
                    fatalError("Sensor authorization failed due to: \(error)")
                } else {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        }
    }
}
