//
//  String+Localization.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

public extension String {
    
    var localized: String {
        return NSLocalizedString(self, bundle: Bundle.main, comment: "")
    }
    
    var languageCode: String {
        return String(self.prefix(2))
    }
}
