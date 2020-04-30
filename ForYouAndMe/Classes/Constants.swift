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
        static let NetworkStubsEnabled = true
        static let NetworkStubsDelay = 0.3
        static let NetworkLogVerbose = false
        
        static let NoCacheGlobalConfig = true
    }
    struct Network {
        static let ApiBaseUrlStr = "https://to.be.defined.base.url" // TODO: Replace with final endpoint
    }
    struct Style {
        static let DefaultHorizontalMargins: CGFloat = 24.0
    }
}
