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
    case permissionRequestError
}

protocol HealthService {
    func requestPermissionDefaultMeasurements() -> Single<()>
}
