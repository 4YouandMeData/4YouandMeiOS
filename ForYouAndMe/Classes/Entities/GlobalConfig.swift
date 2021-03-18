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
    let requiredStringMap: RequiredStringMap
    let fullStringMap: FullStringMap
    let countryCodes: [String]
    let integrationDatas: [IntegrationData]
    let onboardingSectionGroups: [OnboardingSectionGroup]
    let pinCodeLogin: Bool
}

extension GlobalConfig: Codable {
    private enum CodingKeys: CodingKey {
        case colorMapDictionary
        case requiredStringMapDictionary
        case fullStringMapDictionary
        case countryCodesArray
        case integrationDatasArray
        case onboardingSectionGroupsArray
        case pincodeLogin
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.colorMap = try (container.decode(CodableDictionary.self, forKey: .colorMapDictionary).decoded)
            .mapValues { (codableColor: CodableColor) in codableColor.uiColor }
        self.requiredStringMap = try container.decode(CodableDictionary.self, forKey: .requiredStringMapDictionary).decoded
        self.fullStringMap = try container.decode(Dictionary<String, String>.self, forKey: .fullStringMapDictionary)
        self.countryCodes = try container.decode(Array<String>.self, forKey: .countryCodesArray)
        self.integrationDatas = try container.decode(Array<IntegrationData>.self, forKey: .integrationDatasArray)
        self.onboardingSectionGroups = try container.decode(Array<OnboardingSectionGroup>.self, forKey: .onboardingSectionGroupsArray)
        self.pinCodeLogin = try container.decode(Bool.self, forKey: .pincodeLogin)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(CodableDictionary(self.colorMap.mapValues { CodableColor(uiColor: $0) }), forKey: .colorMapDictionary)
        try container.encode(CodableDictionary(self.requiredStringMap), forKey: .requiredStringMapDictionary)
        try container.encode(self.fullStringMap, forKey: .fullStringMapDictionary)
        try container.encode(self.countryCodes, forKey: .countryCodesArray)
        try container.encode(self.integrationDatas, forKey: .integrationDatasArray)
        try container.encode(self.onboardingSectionGroups, forKey: .onboardingSectionGroupsArray)
        try container.encode(self.pinCodeLogin, forKey: .pincodeLogin)
    }
}
