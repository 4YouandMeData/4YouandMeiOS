//
//  LocationService.swift
//  FirebaseCore
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
import RxSwift
import CoreLocation

protocol LocationService {
    var currentPermissionStatus: CLAuthorizationStatus { get }
    func requestPermission(always: Bool) -> Single<()>
}
