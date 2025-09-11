//
//  GlobalConfig.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

struct GlobalConfig {
    let colorMap: ColorMap
    let darkColorMap: ColorMap?
    let requiredStringMap: RequiredStringMap
    let fullStringMap: FullStringMap
    let countryCodes: [String]
    let integrationDatas: [IntegrationData]
    let onboardingSectionGroups: [OnboardingSectionGroup]
    let pinCodeLogin: Bool
    let phaseNames: [String]
    let feedbackList: [String: [EmojiItem]]?

}

extension GlobalConfig: Codable {
    private enum CodingKeys: CodingKey {
        case colorMapDictionary
        case darkColorMapDictionary
        case requiredStringMapDictionary
        case fullStringMapDictionary
        case countryCodesArray
        case integrationDatasArray
        case onboardingSectionGroupsArray
        case pincodeLogin
        case phaseNamesArray
        case feedbackList
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.colorMap = try (container.decode(CodableDictionary.self, forKey: .colorMapDictionary).decoded)
            .mapValues { (codableColor: CodableColor) in codableColor.uiColor }
        // Dark color map (optional)
        if let darkWrap = try container.decodeIfPresent(
            CodableDictionary<ColorType, CodableColor>.self,
            forKey: .darkColorMapDictionary
        ) {
            self.darkColorMap = darkWrap.decoded.mapValues { $0.uiColor }
        } else {
            self.darkColorMap = nil
        }
        self.requiredStringMap = try container.decode(CodableDictionary.self, forKey: .requiredStringMapDictionary).decoded
        self.fullStringMap = try container.decode(Dictionary<String, String>.self, forKey: .fullStringMapDictionary)
        self.countryCodes = try container.decode(Array<String>.self, forKey: .countryCodesArray)
        self.integrationDatas = try container.decode(Array<IntegrationData>.self, forKey: .integrationDatasArray)
        self.onboardingSectionGroups = try container.decode(Array<OnboardingSectionGroup>.self, forKey: .onboardingSectionGroupsArray)
        self.pinCodeLogin = try container.decode(Bool.self, forKey: .pincodeLogin)
        self.phaseNames = try container.decode(Array<String>.self, forKey: .phaseNamesArray)
        self.feedbackList = try container.decode([String: [EmojiItem]].self, forKey: .feedbackList)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(CodableDictionary(self.colorMap.mapValues { CodableColor(uiColor: $0) }), forKey: .colorMapDictionary)
        if let dark = self.darkColorMap {
            try container.encode(CodableDictionary(dark.mapValues { CodableColor(uiColor: $0) }),
                                 forKey: .darkColorMapDictionary)
        }
        try container.encode(CodableDictionary(self.requiredStringMap), forKey: .requiredStringMapDictionary)
        try container.encode(self.fullStringMap, forKey: .fullStringMapDictionary)
        try container.encode(self.countryCodes, forKey: .countryCodesArray)
        try container.encode(self.integrationDatas, forKey: .integrationDatasArray)
        try container.encode(self.onboardingSectionGroups, forKey: .onboardingSectionGroupsArray)
        try container.encode(self.pinCodeLogin, forKey: .pincodeLogin)
        try container.encode(self.phaseNames, forKey: .phaseNamesArray)
        try container.encode(self.feedbackList, forKey: .feedbackList)
    }
    
    func logColorMapDiff(light: ColorMap, dark: ColorMap?) {
        guard let dark else { return }
        let missing = Set(light.keys).subtracting(dark.keys)
        if !missing.isEmpty {
            print("⚠️ Dark map missing overrides for: \(missing.map { $0.rawValue })")
        }
    }
}
