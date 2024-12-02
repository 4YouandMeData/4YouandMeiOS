//
//  ProjectInfo.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/11/2020.
//

import Foundation

class ProjectInfo {
    
    private enum ProjectInfoKey: String, CaseIterable {
        
        case apiBaseUrl = "api_base_url"
        case oauthBaseUrl = "oauth_base_url"
        case studyId = "study_id"
        case pinCodeSuffix = "pin_code_suffix"
        case yourDataUrl = "your_data_url"
    }
    
    static var ApiBaseUrl: String { Self.getValue(forKey: .apiBaseUrl, defaultValue: "") }
    static var OauthBaseUrl: String { Self.getValue(forKey: .oauthBaseUrl, defaultValue: "") }
    static var StudyId: String { Self.getValue(forKey: .studyId, defaultValue: "") }
    static var PinCodeSuffix: String { Self.getValue(forKey: .pinCodeSuffix, defaultValue: "")}
    static var YourDataUrl: String { Self.getValue(forKey: .yourDataUrl, defaultValue: "") }
    
    static func validate() {
        ProjectInfoKey.allCases.forEach { key in
            switch key {
            case .apiBaseUrl: _ = Self.getValue(forKey: key, defaultValue: "")
            case .oauthBaseUrl: _ = Self.getValue(forKey: key, defaultValue: "")
            case .studyId: _ = Self.getValue(forKey: key, defaultValue: "")
            case .pinCodeSuffix: _ = Self.getValue(forKey: key, defaultValue: "")
            case .yourDataUrl: _ = Self.getValue(forKey: key, defaultValue: "")
            }
        }
    }
    
    static private var projectInfoDictionary: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "ProjectInfo", withExtension: "plist") else {
            assertionFailure("Couldn't find ProjectInfo.plist")
            return [:]
        }
        guard let data = try? Data(contentsOf: url) else {
            assertionFailure("Couldn't open ProjectInfo.plist")
            return [:]
        }
        guard let studyConfig = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            assertionFailure("ProjectInfo.plist is not a dictionary of [String: Any]")
            return [:]
        }
        return studyConfig
    }()
    
    static private func getValue<T>(forKey key: ProjectInfoKey, defaultValue: T) -> T {
        guard let object = Self.projectInfoDictionary[key.rawValue], let value = object as? T  else {
            assertionFailure("Couldn't find \(key.rawValue) in ProjectInfo")
            return defaultValue
        }
        return value
    }
}
