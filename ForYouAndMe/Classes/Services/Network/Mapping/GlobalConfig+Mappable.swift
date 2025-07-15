//
//  GlobalConfig+Mappable.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

extension GlobalConfig: Mappable {
    init(map: Mapper) throws {
        try self.colorMap = map.from("color_palette")
        try self.requiredStringMap = map.from("strings")
        try self.fullStringMap = map.from("strings")
        try self.countryCodes = map.from("country_codes", transformation: Mapper.errorIfEmpty)
        try self.integrationDatas = map.from("supported_integrations", transformation: Mapper.extractIntegrationData)
        try self.onboardingSectionGroups = self.requiredStringMap.extractOnboardingSectionGroups()
        try self.pinCodeLogin = map.from("pincode_login")
        self.phaseNames = self.requiredStringMap.extractPhaseNames()
        try self.feedbackList = map.decodeEmojiItemDictionary("feedback_tagging_lists")
    }
}

extension Mapper {
    func from(_ field: String) throws -> ColorMap {
        let dict: [String: String] = try self.from(field)
        
        let colorMap: ColorMap = try dict.reduce([:]) { (result, pair) in
            guard let color = UIColor(hexString: pair.value) else {
                throw MapperError.customError(field: field, message: "Color Value '\(pair.value)' is not convertible to HEX color")
            }
            var result = result
            if let stringKey = ColorType(rawValue: pair.key) {
                result[stringKey] = color
            }
            return result
        }
        
        var check = false
        #if DEBUG
        check = Constants.Test.CheckGlobalColors
        #endif
        if check {
            let keys = colorMap.keys
            try ColorType.allCases.forEach { colorType in
                if false == keys.contains(colorType) {
                    throw MapperError.customError(field: field, message: "Color '\(colorType)' is missing in global config")
                }
            }
        }
        
        return colorMap
    }
    
    func from(_ field: String) throws -> RequiredStringMap {
        let dict: [String: String] = try self.from(field)
        
        let stringMap: RequiredStringMap = dict.reduce([:]) { (result, pair) in
            var result = result
            if let stringKey = StringKey(rawValue: pair.key) {
                result[stringKey] = pair.value
            }
            return result
        }
        
        var check = false
        #if DEBUG
        check = Constants.Test.CheckGlobalStrings
        #endif
        if check {
            let keys = stringMap.keys
            try StringKey.allCases.forEach { stringKey in
                if false == keys.contains(stringKey) {
                    throw MapperError.customError(field: field, message: "String '\(stringKey)' is missing in global config")
                }
            }
        }
        
        return stringMap
    }
    
    static func extractIntegrationData(object: Any?) throws -> [IntegrationData] {
        guard let integrationDatasOuterDict = object as? [String: Any] else {
            throw MapperError.convertibleError(value: object, type: [IntegrationData].self)
        }
        
        return integrationDatasOuterDict.compactMap { integrationDataOuterDictPair in
            let name = integrationDataOuterDictPair.key
            guard let integrationDataInnerDict = integrationDataOuterDictPair.value as? [String: Any] else {
                print("GlobalConfig - Missing integration inner data for integration '\(name)'")
                return nil
            }
            guard let oAuthAvailable = integrationDataInnerDict["oauth"] as? Bool else {
                print("GlobalConfig - Missing ouath data as Boolean for integration '\(name)'")
                return nil
            }
            return IntegrationData(name: name, oAuthAvailable: oAuthAvailable)
        }
    }
    
    func decodeEmojiItemDictionary(_ field: String) throws -> [String: [EmojiItem]] {
        return try self.from(field) { object in
            guard let rawDict = object as? [String: [[String: Any]]] else {
                throw MapperError.typeMismatchError(field: field, value: object, type: [String: [[String: Any]]].self)
            }

            var result: [String: [EmojiItem]] = [:]

            for (key, array) in rawDict {
                let emojiItems: [EmojiItem] = try array.map { item in
                    guard let emoji = item["tag"] as? String else {
                        throw MapperError.customError(field: field, message: "Missing 'tag' in item for key '\(key)'")
                    }
                    let label = item["label"] as? String ?? ""
                    return EmojiItem(tag: emoji, label: label)
                }

                result[key] = emojiItems
            }

            return result
        }
    }
}

fileprivate extension RequiredStringMap {
    func extractOnboardingSectionGroups() throws -> [OnboardingSectionGroup] {
        guard let onboardingSectionGroupListString = self[.onboardingSectionGroupList] else {
            let errorMessage = "Missing list of onboarding section group (key '\(StringKey.onboardingSectionGroupList.rawValue)')"
            throw MapperError.customError(field: "strings", message: errorMessage)
        }
        let onboardingSectionGroupStrings = onboardingSectionGroupListString.split(separator: ";")
        return onboardingSectionGroupStrings.compactMap { OnboardingSectionGroup(rawValue: String($0)) }
    }
    
    func extractPhaseNames() -> [String] {
        guard let phasesListString = self[.phaseNames] else {
            return []
        }
        let phaseStrings = phasesListString.split(separator: ";")
        return phaseStrings.compactMap { String($0) }
    }
    
    func extractMainTabs() throws -> [MainTab] {
            guard let raw = self[.tabBarList] else {
                throw MapperError.customError(
                    field: "strings",
                    message: "Missing TAB_BAR_LIST in strings"
                )
            }
            // Suddividi, mappa e rimuovi eventuali voci non riconosciute
            var tabs = raw
                .split(separator: ";")
                .compactMap { MainTab(configKey: String($0)) }

            // Assicuriamoci che 'feed' sia sempre presente e in testa
            if !tabs.contains(.feed) {
                tabs.insert(.feed, at: 0)
            }
            return tabs
        }
}
