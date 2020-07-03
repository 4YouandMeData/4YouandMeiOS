//
//  Constants.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

enum TestSection {
    case screeningSection
    case informedConsentSection
    case consentSection
    case optInSection
    case consentUserDataSection
}

struct Constants {
    struct Test {
        static let NetworkStubsEnabled = true
        static let NetworkStubsDelay = 0.3
        static let NetworkLogVerbose = true
        
        static let Section: TestSection? = .optInSection
        
        static let InformedConsentWithoutQuestions: Bool = false
    }
    struct Network {
        static let ApiBaseUrlStr = "https://api-4youandme-staging.balzo.eu/api"
    }
    struct Style {
        static let DefaultHorizontalMargins: CGFloat = 24.0
        static let DefaultFooterHeight: CGFloat = 134.0
        static let DefaultTextButtonHeight: CGFloat = 52.0
    }
    struct Resources {
        static let DefaultBundleName: String = "ForYouAndMe"
    }
    struct Misc {
        static let EnableGlobalConfigCache = false
        static let PhoneValidationCodeDigitCount: Int = 6
        static let EmailValidationCodeDigitCount: Int = 6
    }
}
