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
    let stringMap: StringMap
    let countryCodes: [String]
}

extension GlobalConfig: Codable {
    private enum CodingKeys: CodingKey {
        case colorMapDictionary
        case stringMapDictionary
        case countryCodesArray
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.colorMap = try (container.decode(CodableDictionary.self, forKey: .colorMapDictionary).decoded)
            .mapValues { (codableColor: CodableColor) in codableColor.uiColor }
        self.stringMap = try container.decode(CodableDictionary.self, forKey: .stringMapDictionary).decoded
        self.countryCodes = try container.decode(Array<String>.self, forKey: .countryCodesArray)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(CodableDictionary(self.colorMap.mapValues { CodableColor(uiColor: $0) }), forKey: .colorMapDictionary)
        try container.encode(CodableDictionary(self.stringMap), forKey: .stringMapDictionary)
        try container.encode(self.countryCodes, forKey: .countryCodesArray)
    }
}
