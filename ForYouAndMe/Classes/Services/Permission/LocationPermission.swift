//
//  LocationPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 18/09/2020.
//

import UIKit
import MapKit

struct LocationPermission: PermissionProtocol {
    
    var type: LocationType
    
    enum LocationType {
        case whenInUse
        #if os(iOS)
        case alwaysAndWhenInUse
        #endif
    }
    
    init(type: LocationType) {
        self.type = type
    }
    
    var isAuthorized: Bool {
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways {
            return true
        } else {
            if type == .whenInUse {
                return status == .authorizedWhenInUse
            } else {
                return false
            }
        }
    }
    
    var isDenied: Bool {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        return authorizationStatus == .denied
    }
    
    var isRestricted: Bool {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        return authorizationStatus == .restricted
    }
    
    var isNotDetermined: Bool {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        return authorizationStatus == .notDetermined
    }
    
    func request(completion: @escaping () -> Void?) {
        
        switch self.type {
        #if os(iOS)
        case .alwaysAndWhenInUse:
            if PermissionAlwaysLocationHandler.shared == nil {
                PermissionAlwaysLocationHandler.shared = PermissionAlwaysLocationHandler()
            }
            
            PermissionAlwaysLocationHandler.shared!.requestPermission { authorized in
                DispatchQueue.main.async {
                    if authorized {
                        Services.shared.deviceService.onLocationPermissionGranted()
                    }
                    completion()
                    PermissionAlwaysLocationHandler.shared = nil
                }
            }
        #endif
        case .whenInUse:
            if PermissionWhenInUseLocationHandler.shared == nil {
                PermissionWhenInUseLocationHandler.shared = PermissionWhenInUseLocationHandler()
            }
            
            PermissionWhenInUseLocationHandler.shared!.requestPermission { authorized in
                DispatchQueue.main.async {
                    if authorized {
                        Services.shared.deviceService.onLocationPermissionGranted()
                    }
                    completion()
                    PermissionWhenInUseLocationHandler.shared = nil
                }
            }
        }
    }
}
