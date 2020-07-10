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
    case wearablesSection
}

struct Constants {
    struct Test {
        static let NetworkStubsEnabled = false
        static let NetworkStubsDelay = 0.3
        static let NetworkLogVerbose = true
        
        static let Section: TestSection? = nil//.informedConsentSection
        
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
    
    struct Url {
        static let OuraStoreUrl: URL = URL(string: "itms-apps://apps.apple.com/it/app/oura/id1043837948")!
        static let OuraAppSchema: URL = URL(string: "oura://")!
        static let FitbitStoreUrl: URL = URL(string: "itms-apps://apps.apple.com/us/app/fitbit-health-fitness/id462638897")!
        static let FitbitAppSchema: URL = URL(string: "fitbit://")!
    }
}
