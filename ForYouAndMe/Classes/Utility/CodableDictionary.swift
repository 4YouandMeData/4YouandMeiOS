//
//  CodableDictionary.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

struct CodableDictionary<Key: Hashable, Value: Codable>: Codable where Key: CodingKey {

    let decoded: [Key: Value]

    init(_ decoded: [Key: Value]) {
        self.decoded = decoded
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: Key.self)

        self.decoded = Dictionary(uniqueKeysWithValues:
            try container.allKeys.lazy.map {
                (key: $0, value: try container.decode(Value.self, forKey: $0))
            }
        )
    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.container(keyedBy: Key.self)

        for (key, value) in self.decoded {
            try container.encode(value, forKey: key)
        }
    }
}
