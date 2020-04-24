//
//  Bundle+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

public extension Bundle {
    
    var versionName: String {
        if let dictionary = self.infoDictionary, let version = dictionary["CFBundleShortVersionString"] as? String {
            return version
        }
        assertionFailure("Couldn't get version")
        return ""
    }
    
    var buildNumber: Int {
        if let dictionary = self.infoDictionary,
            let buildString = dictionary["CFBundleVersion"] as? String,
            let buildNumber = Int(buildString) {
            return buildNumber
        }
        assertionFailure("Couldn't get build number")
        return 0
    }
    
    var appLanguageCode: String {
        return self.preferredLocalizations.first?.languageCode ?? "en"
    }
}
