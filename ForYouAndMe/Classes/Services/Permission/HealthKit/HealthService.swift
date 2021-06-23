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
}
