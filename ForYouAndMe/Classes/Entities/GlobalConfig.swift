//
//  GlobalConfig.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//

import Foundation

struct GlobalConfig {
    let colorMap: ColorMap
    let stringMap: StringMap
}

extension GlobalConfig: Codable {
    private enum CodingKeys: CodingKey {
        case colorMapDictionary
        case stringMapDictionary
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.colorMap = try (container.decode(CodableDictionary.self, forKey: .colorMapDictionary).decoded)
            .mapValues { (codableColor: CodableColor) in codableColor.uiColor }
        self.stringMap = try container.decode(CodableDictionary.self, forKey: .stringMapDictionary).decoded
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(CodableDictionary(self.colorMap.mapValues { CodableColor(uiColor: $0) }), forKey: .colorMapDictionary)
        try container.encode(CodableDictionary(self.stringMap), forKey: .stringMapDictionary)
    }
}
