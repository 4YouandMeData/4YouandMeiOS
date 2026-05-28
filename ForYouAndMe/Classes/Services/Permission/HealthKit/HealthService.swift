//
//  HealthService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
import RxSwift

enum HealthError: Error {
    case healthKitNotAvailable
    case permissionRequestError(underlyingError: Error?)
    case getPermissionRequestStatusError(underlyingError: Error?)
}

protocol HealthService {
    var serviceAvailable: Bool { get }
    func requestPermissions() -> Single<()>
    func getIsAuthorizationStatusUndetermined() -> Single<Bool>
    /// `true` iff the HealthKit authorization status for the configured read types
    /// is `.shouldRequest` — i.e. the system still wants to display the prompt.
    /// After a successful `requestPermissions()` this is expected to be `false`
    /// (status `.unnecessary`). If it is still `true`, the system silently refused
    /// to display the prompt and the caller should surface a settings alert.
    func isStillShouldRequest() -> Single<Bool>
}
