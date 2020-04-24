//
//  Repository.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

enum RepositoryError: LocalizedError {
    // Authentication
    case userNotLoggedIn
    
    // Server
    case remoteServerError
    
    // Shared
    case connectivityError
    case genericError
    
    var errorDescription: String? {
        switch self {
        // Authentication
        case .userNotLoggedIn: return "USER_AUTHENTICATION_ERROR_USER_NOT_LOGGED_IN".localized
            
        // Server
        case .remoteServerError: return "GENERIC_ERROR_REMOTE_SERVER".localized
            
        // Shared
        case .connectivityError: return "GENERIC_ERROR_CONNECTIVITY_MESSAGE".localized
        case .genericError: return "GENERIC_ERROR_DEFAULT".localized
        }
    }
}

protocol Repository: class {
    // Authentication
    var isLoggedIn: Bool { get }
}
