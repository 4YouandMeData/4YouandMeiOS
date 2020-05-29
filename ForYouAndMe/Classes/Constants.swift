//
//  Constants.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

enum TestNavigationStep {
    case screeningQuestions
}

struct Constants {
    struct Test {
        static let NetworkStubsEnabled = true
        static let NetworkStubsDelay = 1.3
        static let NetworkLogVerbose = false
        
        static let NoCacheGlobalConfig = true
        static let NavigationStep: TestNavigationStep? = nil//.screeningQuestions
    }
    struct Network {
        static let ApiBaseUrlStr = "https://api-4youandme-staging.balzo.eu/api"
    }
    struct Style {
        static let DefaultHorizontalMargins: CGFloat = 24.0
        static let DefaultFooterButtonHeight: CGFloat = 116.0
    }
    struct Resources {
        static let DefaultBundleName: String = "ForYouAndMe"
    }
    struct Misc {
        static let ValidationCodeDigitCount: Int = 6
    }
}
