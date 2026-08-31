//
//  ProjectInfo.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/11/2020.
//

import Foundation

/// Note type a host app can offer when creating a diary note or a reflection (FUAM-4031).
enum HostAppNoteType: String, CaseIterable {
    case text
    case audio
    case video
}

/// Host-app configuration flags read from the HOST app's `Info.plist` (NOT `ProjectInfo.plist`).
/// Absent keys default to `false`, which preserves the pre-existing behaviour — a missing key
/// is a valid, expected state, so no assertion is raised and these keys are deliberately
/// excluded from `ProjectInfo.validate()`.
/// `Bundle.main` is read synchronously so these flags are available before any network call
/// (e.g. `SensorKitManager.initialize()` runs before `RepositoryImpl.initialize()` in `Services.setup`).
enum HostAppConfig {
    static var healthKitIgnoresOptInConsent: Bool { flag("FYAMHealthKitIgnoreOptInConsent") }
    static var sensorKitIgnoresOptInConsent: Bool { flag("FYAMSensorKitIgnoreOptInConsent") }

    /// Note types offered by the "I have noticed" chooser and the diary list footer.
    static var diaryNoteTypes: [HostAppNoteType] { noteTypes("FYAMDiaryNoteTypes") }
    /// Note types offered by the reflection task start page.
    static var reflectionTypes: [HostAppNoteType] { noteTypes("FYAMReflectionTypes") }

    /// The only diary note type allowed, when the host app narrowed the setting down to one.
    static var singleDiaryNoteType: HostAppNoteType? {
        let types = self.diaryNoteTypes
        return types.count == 1 ? types.first : nil
    }

    private static func flag(_ key: String) -> Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else { return false }
        if let bool = value as? Bool { return bool }
        assertionFailure("\(key) must be a Boolean in Info.plist, got \(type(of: value))")
        return (value as? NSString)?.boolValue ?? false
    }

    /// Lenient on purpose: a missing key, a malformed value, an empty array or an array with no
    /// recognised entry all mean "every type", which is the behaviour of every host app that
    /// doesn't set the key. Unknown strings are ignored.
    private static func noteTypes(_ key: String) -> [HostAppNoteType] {
        let rawValues = (Bundle.main.object(forInfoDictionaryKey: key) as? [String] ?? []).map { $0.lowercased() }
        let types = HostAppNoteType.allCases.filter { rawValues.contains($0.rawValue) }
        return types.isEmpty ? HostAppNoteType.allCases : types
    }
}

class ProjectInfo {
    
    private enum ProjectInfoKey: String, CaseIterable {
        
        case apiBaseUrl = "api_base_url"
        case oauthBaseUrl = "oauth_base_url"
        case studyId = "study_id"
        case pinCodeSuffix = "pin_code_suffix"
        case yourDataUrl = "your_data_url"
        case terraDevID = "terra_dev_id"
    }
    
    static var ApiBaseUrl: String { Self.getValue(forKey: .apiBaseUrl, defaultValue: "") }
    static var OauthBaseUrl: String { Self.getValue(forKey: .oauthBaseUrl, defaultValue: "") }
    static var StudyId: String { Self.getValue(forKey: .studyId, defaultValue: "") }
    static var PinCodeSuffix: String { Self.getValue(forKey: .pinCodeSuffix, defaultValue: "")}
    static var YourDataUrl: String { Self.getValue(forKey: .yourDataUrl, defaultValue: "") }
    static var TerraDevID: String { Self.getValue(forKey: .terraDevID, defaultValue: "")}
    
    static func validate() {
        ProjectInfoKey.allCases.forEach { key in
            switch key {
            case .apiBaseUrl: _ = Self.getValue(forKey: key, defaultValue: "")
            case .oauthBaseUrl: _ = Self.getValue(forKey: key, defaultValue: "")
            case .studyId: _ = Self.getValue(forKey: key, defaultValue: "")
            case .pinCodeSuffix: _ = Self.getValue(forKey: key, defaultValue: "")
            case .yourDataUrl: _ = Self.getValue(forKey: key, defaultValue: "")
            case .terraDevID: _ = Self.getValue(forKey: key, defaultValue: "")
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
