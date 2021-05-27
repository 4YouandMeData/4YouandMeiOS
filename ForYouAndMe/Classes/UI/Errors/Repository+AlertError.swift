//
//  Repository+AlertError.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/09/2020.
//

import Foundation

extension RepositoryError: AlertError {
    var errorDescription: String? {
        switch self {
        // Authentication
        case .userNotLoggedIn: return "User not logged In"
            
        // Server
        case .remoteServerError: return StringsProvider.string(forKey: .errorMessageRemoteServer)
        case .serverErrorSpecific: return StringsProvider.string(forKey: .errorMessageRemoteServer)
            
        // Login
        case .missingPhoneNumber: return StringsProvider.string(forKey: .phoneVerificationErrorMissingNumber)
        case .wrongPhoneValidationCode: return StringsProvider.string(forKey: .phoneVerificationErrorWrongCode)
        
        // Onboarding
        case .wrongEmailValidationCode: return StringsProvider.string(forKey: .onboardingUserEmailVerificationErrorWrongCode)
            
        // Shared
        case .connectivityError: return StringsProvider.string(forKey: .errorMessageConnectivity)
        case .genericError: return StringsProvider.string(forKey: .errorMessageDefault)
            
        // Debug
        case .debugError(let error): return error.description
        }
    }
}
