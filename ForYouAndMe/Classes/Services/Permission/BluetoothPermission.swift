//
//  BluetoothPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import CoreBluetooth

class BluetoothPermission: NSObject, PermissionProtocol {
    
    typealias SPBluetoothPermissionHandler = () -> Void?
    private var completion: SPBluetoothPermissionHandler?
    private var manager: CBCentralManager?
    
    var isAuthorized: Bool {
        if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .allowedAlways
        }
        return CBPeripheralManager.authorizationStatus() == .authorized
    }
    
    var isDenied: Bool {
        if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .denied
        }
        return CBPeripheralManager.authorizationStatus() == .denied
    }
    
    var isRestricted: Bool {
        if #available(iOS 13.0, *) {
                   return CBCentralManager().authorization == .restricted
               }
        return CBPeripheralManager.authorizationStatus() == .restricted
    }
    
    var isNotDetermined: Bool {
        if #available(iOS 13.0, *) {
                   return CBCentralManager().authorization == .notDetermined
               }
        return CBPeripheralManager.authorizationStatus() == .notDetermined
    }
    
    func request(completion: @escaping ()->()?) {
        self.completion = completion
        self.manager = CBCentralManager(delegate: self, queue: nil, options: [:])
    }
}

extension BluetoothPermission: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 13.0, *) {
            switch central.authorization {
            case .notDetermined:
                break
            default:
                self.completion?()
            }
        } else {
            switch CBPeripheralManager.authorizationStatus() {
            case .notDetermined:
                break
            default:
                self.completion?()
            }
        }
    }
}
