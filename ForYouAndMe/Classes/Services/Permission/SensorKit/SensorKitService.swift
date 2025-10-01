//
//  SensorKitService.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import RxSwift

enum SensorKitError: Error {
    case sensorkitNotAvailable
    case permissionRequestError(underlyingError: Error?)
}

protocol SensorKitService {
    /// True if the service can run on this device/build (entitlements, device class, etc.)
    var serviceAvailable: Bool { get }

    /// Ask for SensorKit permissions for the configured sensors.
    func requestPermissions() -> Single<()>

    /// Returns true if at least one required sensor permission is undetermined.
    func getIsAuthorizationStatusUndetermined() -> Single<Bool>
}
