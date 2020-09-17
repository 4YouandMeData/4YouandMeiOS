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
        return CBCentralManager().authorization == .allowedAlways
    }
    
    var isDenied: Bool {
        return CBCentralManager().authorization == .denied
    }
    
    var isRestricted: Bool {
        return CBCentralManager().authorization == .restricted
    }
    
    var isNotDetermined: Bool {
        return CBCentralManager().authorization == .notDetermined
    }
    
    func request(completion: @escaping () -> Void?) {
        self.completion = completion
        self.manager = CBCentralManager.init(delegate: self, queue: nil, options: [:])
    }
}

extension BluetoothPermission: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.authorization {
        case .notDetermined:
            break
        default:
            self.completion?()
        }
    }
}
