//
//  NotificationService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/10/2020.
//

import Foundation
import RxSwift

enum NotificationError: Error {
    case fetchRegistrationTokenError
}

protocol NotificationService {
    func getRegistrationToken() -> Single<String?>
}
