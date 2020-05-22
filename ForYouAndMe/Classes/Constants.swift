//
//  Constants.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

struct Constants {
    struct Test {
        static let NetworkStubsEnabled = false
        static let NetworkStubsDelay = 0.3
        static let NetworkLogVerbose = true
        
        static let NoCacheGlobalConfig = true
    }
    struct Network {
        static let ApiBaseUrlStr = "https://api-4youandme-staging.balzo.eu/api"
    }
    struct Style {
        static let DefaultHorizontalMargins: CGFloat = 24.0
        static let DefaultFooterButtonHeight: CGFloat = 116.0
    }
    struct Misc {
        static let ValidationCodeDigitCount: Int = 6
    }
}
