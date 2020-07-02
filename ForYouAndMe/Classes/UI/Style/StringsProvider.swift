//
//  StringsProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

typealias StringMap = [StringKey: String]

enum StringKey: String, CaseIterable, CodingKey {
    // Setup
    case setupErrorTitle = "SETUP_ERROR_TITLE"
    // Welcome
    case welcomeStartButton = "WELCOME_START_BUTTON"
    // Intro
    case introTitle = "INTRO_TITLE"
    case introBody = "INTRO_BODY"
    case introLogin = "INTRO_LOGIN"
    case introSetupLater = "INTRO_BACK"
    // Setup Later
    case setupLaterBody = "SETUP_LATER_BODY"
    case setupLaterConfirmButton = "SETUP_LATER_CONFIRM_BUTTON"
    // Phone Verification
    case phoneVerificationTitle = "PHONE_VERIFICATION_TITLE"
    case phoneVerificationBody = "PHONE_VERIFICATION_BODY"
    case phoneVerificationNumberDescription = "PHONE_VERIFICATION_NUMBER_DESCRIPTION"
    case phoneVerificationCountryPickerTitle = "PHONE_VERIFICATION_COUNTRY_PICKER_TITLE"
    case phoneVerificationLegal = "PHONE_VERIFICATION_LEGAL"
    case phoneVerificationLegalTermsOfService = "PHONE_VERIFICATION_LEGAL_TERMS_OF_SERVICE"
    case phoneVerificationLegalPrivacyPolicy = "PHONE_VERIFICATION_LEGAL_PRIVACY_POLICY"
    case phoneVerificationWrongNumber = "PHONE_VERIFICATION_WRONG_NUMBER"
    case phoneVerificationCodeTitle = "PHONE_VERIFICATION_CODE_TITLE"
    case phoneVerificationCodeBody = "PHONE_VERIFICATION_CODE_BODY"
    case phoneVerificationCodeDescription = "PHONE_VERIFICATION_CODE_DESCRIPTION"
    case phoneVerificationCodeResend = "PHONE_VERIFICATION_CODE_RESEND"
    case phoneVerificationErrorWrongCode = "PHONE_VERIFICATION_ERROR_WRONG_CODE"
    case phoneVerificationErrorMissingNumber = "PHONE_VERIFICATION_ERROR_MISSING_NUMBER"
    // Onboarding
    case onboardingAbortButton = "ONBOARDING_ABORT_BUTTON"
    case onboardingAbortTitle = "ONBOARDING_ABORT_TITLE"
    case onboardingAbortMessage = "ONBOARDING_ABORT_MESSAGE"
    case onboardingAbortConfirm = "ONBOARDING_ABORT_CONFIRM"
    case onboardingAbortCancel = "ONBOARDING_ABORT_CANCEL"
    case onboardingAgreeButton = "ONBOARDING_AGREE_BUTTON"
    case onboardingDisagreeButton = "ONBOARDING_DISAGREE_BUTTON"
    case onboardingOptInMandatoryClose = "ONBOARDING_OPT_IN_MANDATORY_CLOSE"
    case onboardingOptInMandatoryTitle = "ONBOARDING_OPT_IN_MANDATORY_TITLE"
    case onboardingOptInMandatoryDefault = "ONBOARDING_OPT_IN_MANDATORY_DEFAULT"
    case onboardingOptInSubmitButton = "ONBOARDING_OPT_IN_SUBMIT_BUTTON"
    case onboardingUserNameTitle = "ONBOARDING_USER_NAME_TITLE"
    case onboardingUserNameFirstNameDescription = "ONBOARDING_USER_NAME_FIRST_NAME_DESCRIPTION"
    case onboardingUserNameLastNameDescription = "ONBOARDING_USER_NAME_LAST_NAME_DESCRIPTION"
    case onboardingUserEmailEmailDescription = "ONBOARDING_USER_EMAIL_EMAIL_DESCRIPTION"
    case onboardingUserEmailInfo = "ONBOARDING_USER_EMAIL_INFO"
    case onboardingUserEmailVerificationTitle = "ONBOARDING_USER_EMAIL_VERIFICATION_TITLE"
    case onboardingUserEmailVerificationBody = "ONBOARDING_USER_EMAIL_VERIFICATION_BODY"
    case onboardingUserEmailVerificationWrongEmail
        = "ONBOARDING_USER_EMAIL_VERIFICATION_WRONG_EMAIL"
    case onboardingUserEmailVerificationCodeDescription
        = "ONBOARDING_USER_EMAIL_VERIFICATION_CODE_DESCRIPTION"
    case onboardingUserEmailVerificationErrorWrongCode
        = "ONBOARDING_USER_EMAIL_VERIFICATION_ERROR_WRONG_CODE"
    case onboardingUserEmailVerificationResend = "ONBOARDING_USER_EMAIL_VERIFICATION_RESEND"
    case onboardingUserSignatureTitle = "ONBOARDING_USER_SIGNATURE_TITLE"
    case onboardingUserSignatureBody = "ONBOARDING_USER_SIGNATURE_BODY"
    case onboardingUserSignaturePlaceholder = "ONBOARDING_USER_SIGNATURE_PLACEHOLDER"
    case onboardingUserSignatureClear = "ONBOARDING_USER_SIGNATURE_CLEAR"
    // Generic
    case genericInfoTitle = "GENERIC_INFO_TITLE"
    
    // Errors
    case errorTitleDefault = "ERROR_TITLE_DEFAULT"
    case errorButtonCancel = "ERROR_BUTTON_CANCEL"
    case errorButtonRetry = "ERROR_BUTTON_RETRY"
    case errorButtonClose = "ERROR_BUTTON_CLOSE"
    case errorMessageDefault = "ERROR_MESSAGE_DEFAULT"
    case errorMessageRemoteServer = "ERROR_MESSAGE_REMOTE_SERVER"
    case errorMessageConnectivity = "ERROR_MESSAGE_CONNECTIVITY"
    
    // Urls
    case urlPrivacyPolicy = "URL_PRIVACY_POLICY"
    case urlTermsOfService = "URL_TERMS_OF_SERVICE"
    
    var defaultValue: String {
        switch self {
        case .setupErrorTitle: return "Uh, oh!"
        case .genericInfoTitle: return "Info"
        case .errorTitleDefault: return "Error"
        case .errorButtonCancel: return "Cancel"
        case .errorButtonRetry: return "Try again"
        case .errorButtonClose: return "Ok"
        case .errorMessageDefault: return "Something went wrong,\nplease try again"
        case .errorMessageRemoteServer: return "Something went wrong,\nplease try again"
        case .errorMessageConnectivity: return "You seem to be offline.\nPlease check your internet connection and try again."
        default: return ""
        }
    }
}

class StringsProvider {
    
    private static var stringMap: StringMap = [:]
    
    static func initialize(withStringMap stringMap: StringMap) {
        self.stringMap = stringMap
    }
    
    static func string(forKey key: StringKey) -> String {
        return self.stringMap[key] ?? key.defaultValue
    }
}
