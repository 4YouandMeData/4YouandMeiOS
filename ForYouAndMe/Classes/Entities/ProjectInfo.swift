//
//  ProjectInfo.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/11/2020.
//

import Foundation

protocol AnyType {}

class ProjectInfo {
    
    private enum ProjectInfoKey: String, CaseIterable {
        
        case baseUrl = "base_url"
        case studyId = "study_id"
    }
    
    static var BaseUrl: String { Self.getValue(forKey: .baseUrl, defaultValue: "") }
    static var StudyId: String { Self.getValue(forKey: .studyId, defaultValue: "") }
    
    static func validate() {
        ProjectInfoKey.allCases.forEach { key in
            switch key {
            case .baseUrl: _ = Self.getValue(forKey: key, defaultValue: "")
            case .studyId: _ = Self.getValue(forKey: key, defaultValue: "")
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
