//
//  StringsProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//

import UIKit

typealias StringMap = [StringKey: String]

enum StringKey: String, CaseIterable {
    case welcomeStartButton = "WELCOME_START_BUTTON"
}

class StringsProvider {
    
    private static var stringMap: StringMap = [:]
    
    static func initialize(withStringMap stringMap: StringMap) {
        self.stringMap = stringMap
    }
    
    static func string(forKey key: StringKey) -> String {
        return self.stringMap[key] ?? ""
    }
}
