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

/// Outcome of the setup-time permission request, distinguishing a normal completion
/// from the case where the system-wide SensorKit master switch ("Sensor & Usage Data
/// Collection") is OFF and iOS refuses to show any prompt (FUAM-3432).
enum SensorKitSetupOutcome {
    case completed
    case collectionDisabledSystemWide
}

protocol SensorKitService {
    /// True if the service can run on this device/build (entitlements, device class, etc.)
    var serviceAvailable: Bool { get }

    /// Ask for SensorKit permissions for the configured sensors.
    func requestPermissions() -> Single<()>

    /// Ask for SensorKit permissions for the not-determined sensors, detecting when the
    /// system-wide SensorKit collection switch is OFF (a `promptDeclined` error). Emits
    /// `.collectionDisabledSystemWide` the moment that error is seen (short-circuit), or
    /// `.completed` when the whole loop finishes without it.
    func requestPermissionsDetectingCollectionDisabled() -> Single<SensorKitSetupOutcome>

    /// Returns true if at least one required sensor permission is undetermined.
    func getIsAuthorizationStatusUndetermined() -> Single<Bool>
}
