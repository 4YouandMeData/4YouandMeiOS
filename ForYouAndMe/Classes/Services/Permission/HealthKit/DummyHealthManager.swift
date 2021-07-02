//
//  DummyHealthManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/21.
//

import Foundation
import RxSwift

class DummyHealthManager: HealthService {
    
    var serviceAvailable: Bool { false }
    
    func requestPermissions() -> Single<()> {
        assertionFailure("Unexpected health permission request. The HEALTHKIT compilation condition has not been defined")
        return Single.error(HealthError.healthKitNotAvailable)
    }
    
    func getIsAuthorizationStatusUndetermined() -> Single<Bool> {
        assertionFailure("Unexpected get authorization status. The HEALTHKIT compilation condition has not been defined")
        return Single.error(HealthError.healthKitNotAvailable)
    }
}
