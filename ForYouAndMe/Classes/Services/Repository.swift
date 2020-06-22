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
    case serverErrorSpecific(error: Any)
    
    // Login
    case missingPhoneNumber
    case wrongPhoneValidationCode
    
    // Onboarding
    case wrongEmailValidationCode
    
    // Shared
    case connectivityError
    case genericError
    
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
        }
    }
}

protocol Repository: class {
    // Authentication
    var isLoggedIn: Bool { get }
    func logOut()
    func submitPhoneNumber(phoneNumber: String) -> Single<()>
    func verifyPhoneNumber(phoneNumber: String, validationCode: String) -> Single<()>
    // Screening Section
    func getScreeningSection() -> Single<ScreeningSection>
    // Informed Consent Section
    func getInformedConsentSection() -> Single<InformedConsentSection>
    // Consent Section
    func getConsentSection() -> Single<ConsentSection>
    // User Consent Section
    func getUserConsentSection() -> Single<ConsentUserDataSection>
    func submitEmail(email: String) -> Single<()>
    func verifyEmail(validationCode: String) -> Single<()>
    func resendConfirmationEmail() -> Single<()>
    func sendUserData(firstName: String, lastName: String, signatureImage: UIImage) -> Single<()>
}
