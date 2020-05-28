//
//  PropertyWrappers.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

@propertyWrapper
struct FailableDecodable<Wrapped: Decodable>: Decodable {
    var wrappedValue: Wrapped?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try? container.decode(Wrapped.self)
    }
}
