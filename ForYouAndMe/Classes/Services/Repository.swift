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
}

protocol Repository: class {
    // Authentication
    var accessToken: String? { get }
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
    // Opt In Section
    func getOptInSection() -> Single<OptInSection>
    func sendOptInPermission(permission: OptInPermission, granted: Bool) -> Single<()>
    // User Consent Section
    func getUserConsentSection() -> Single<ConsentUserDataSection>
    func submitEmail(email: String) -> Single<()>
    func verifyEmail(validationCode: String) -> Single<()>
    func resendConfirmationEmail() -> Single<()>
    func sendUserData(firstName: String, lastName: String, signatureImage: UIImage) -> Single<()>
    // Wearables Section
    func getWearablesSection() -> Single<WearablesSection>
    // Tasks
    func getFeeds() -> Single<[Feed]>
    func sendQuickActivityResult(quickActivityTaskId: String, quickActivityOption: QuickActivityOption) -> Single<()>
    func sendTaskResult(taskId: String, taskResult: TaskNetworkResult) -> Single<()>
    // User
    func sendUserInfoParameters(userParameterRequests: [UserInfoParameterRequest]) -> Single<()>
}
