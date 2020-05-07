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
        case .userNotLoggedIn: return "User not logged In"
            
        // Server
        case .remoteServerError: return StringsProvider.string(forKey: .errorMessageRemoteServer)
            
        // Shared
        case .connectivityError: return StringsProvider.string(forKey: .errorMessageConnectivity)
        case .genericError: return StringsProvider.string(forKey: .errorMessageDefault)
        }
    }
}

protocol Repository: class {
    // Authentication
    var isLoggedIn: Bool { get }
    func submitPhoneNumber(phoneNumber: String) -> Single<()>
    func varifyPhoneNumber(phoneNumber: String, secureCode: String) -> Single<()>
}
