//
//  LocationManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
import CoreLocation
import RxSwift

class LocationManager: NSObject, LocationService {
    
    var currentPermissionStatus: CLAuthorizationStatus { CLLocationManager.authorizationStatus() }
    
    private let locationManager: CLLocationManager
    
    private var permissionStatusSingleEvent: ((SingleEvent<()>) -> Void)?
    
    override init() {
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.delegate = self
    }
    
    func requestPermission(always: Bool) -> Single<()> {
        // According to iOS doc, the native alert is shown only if the current state is .notDetermined.
        guard self.currentPermissionStatus == .notDetermined else {
            return Single.just(())
        }
        
        return Single<()>.create(subscribe: { [weak self] singleEvent -> Disposable in
            guard let self = self else { return Disposables.create() }
            self.permissionStatusSingleEvent = singleEvent
            if always {
                self.locationManager.requestAlwaysAuthorization()
            } else {
                self.locationManager.requestWhenInUseAuthorization()
            }
            return Disposables.create()
        })
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if let singleEvent = self.permissionStatusSingleEvent {
            singleEvent(.success(()))
            self.permissionStatusSingleEvent = nil
        }
    }
}
