//
//  PermissionLocationHandler.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 18/09/2020.
//

import Foundation
import MapKit

#if os(iOS)
class PermissionAlwaysLocationHandler: NSObject, CLLocationManagerDelegate {
    
    static var shared: PermissionAlwaysLocationHandler?
    
    lazy var locationManager: CLLocationManager =  {
        return CLLocationManager()
    }()
    
    var completionHandler: PermissionHandlerCompletionBlock?
    
    override init() {
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined {
            return
        }

        if let completionHandler = completionHandler {
            completionHandler(self.isAuthorized)
        }
    }
    
    private var whenInUseNotRealChangeStatus: Bool = false
    
    func requestPermission(_ completionHandler: @escaping PermissionHandlerCompletionBlock) {
        self.completionHandler = completionHandler
        
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .notDetermined:
            locationManager.delegate = self
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            locationManager.delegate = self
            locationManager.requestAlwaysAuthorization()
            self.whenInUseNotRealChangeStatus = true
        default:
            completionHandler(self.isAuthorized)
        }
    }
    
    var isAuthorized: Bool {
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways {
            return true
        }
        return false
    }
    
    deinit {
        locationManager.delegate = nil
    }
}
#endif

class PermissionWhenInUseLocationHandler: NSObject, CLLocationManagerDelegate {
    
    static var shared: PermissionWhenInUseLocationHandler?
    
    lazy var locationManager: CLLocationManager =  {
        return CLLocationManager()
    }()
    
    var completionHandler: PermissionHandlerCompletionBlock?
    
    override init() {
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .notDetermined {
            return
        }
        
        if let completionHandler = completionHandler {
            completionHandler(self.isAuthorized)
        }
    }
    
    func requestPermission(_ completionHandler: @escaping PermissionHandlerCompletionBlock) {
        self.completionHandler = completionHandler
        
        let status = CLLocationManager.authorizationStatus()
        if (status == .notDetermined) || (status == .authorizedAlways) {
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
        } else {
            completionHandler(self.isAuthorized)
        }
    }
    
    var isAuthorized: Bool {
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedWhenInUse {
            return true
        }
        return false
    }
    
    deinit {
        locationManager.delegate = nil
    }
}

#if os(iOS)
extension PermissionAlwaysLocationHandler {
    
    typealias PermissionHandlerCompletionBlock = (Bool) -> Void
}
#endif

extension PermissionWhenInUseLocationHandler {
    
    typealias PermissionHandlerCompletionBlock = (Bool) -> Void
}
