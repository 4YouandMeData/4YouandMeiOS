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
    
    // Generic
    case genericInfoTitle = "GENERIC_INFO_TITLE"
    
    // Errors
    case errorTitleDefault = "ERROR_TITLE_TITLE"
    case errorButtonCancel = "ERROR_BUTTON_CANCEL"
    case errorButtonRetry = "ERROR_BUTTON_RETRY"
    case errorMessageDefault = "ERROR_MESSAGE_DEFAULT"
    case errorMessageRemoteServer = "ERROR_MESSAGE_REMOTE_SERVER"
    case errorMessageConnectivity = "ERROR_MESSAGE_CONNECTIVITY"
    
    var defaultValue: String {
        switch self {
        case .setupErrorTitle: return "Uh, oh!"
        case .genericInfoTitle: return "Info"
        case .errorTitleDefault: return "Error"
        case .errorButtonCancel: return "Cancel"
        case .errorButtonRetry: return "Try again"
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
