//
//  GlobalConfig+Mappable.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Mapper

extension GlobalConfig: Mappable {
    init(map: Mapper) throws {
        try self.colorMap = map.from("color_palette")
        try self.stringMap = map.from("strings")
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
        
        let keys = colorMap.keys
        try ColorType.allCases.forEach { colorType in
            if false == keys.contains(colorType) {
                throw MapperError.customError(field: field, message: "Color '\(colorType)' is missing in global config")
            }
        }
        
        return colorMap
    }
    
    func from(_ field: String) throws -> StringMap {
        let dict: [String: String] = try self.from(field)
        
        let stringMap: StringMap = dict.reduce([:]) { (result, pair) in
            var result = result
            if let stringKey = StringKey(rawValue: pair.key) {
                result[stringKey] = pair.value
            }
            return result
        }
        
        let keys = stringMap.keys
        try StringKey.allCases.forEach { stringKey in
            if false == keys.contains(stringKey) {
                throw MapperError.customError(field: field, message: "String '\(stringKey)' is missing in global config")
            }
        }
        
        return stringMap
    }
}
