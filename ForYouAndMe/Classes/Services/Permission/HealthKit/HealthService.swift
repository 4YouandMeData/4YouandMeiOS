//
//  HealthService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import Foundation
import RxSwift

public enum HealthReadType {
    case stepCount
    case bloodType
}

enum HealthError: Error {
    case healthKitNotAvailable
    case permissionRequestError(underlyingError: Error?)
}

protocol HealthService {
    func requestPermissions() -> Single<()>
}
