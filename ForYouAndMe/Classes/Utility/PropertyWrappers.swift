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

@propertyWrapper
struct NilIfEmptyString: Decodable {
    var wrappedValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self), false == string.isEmpty {
            self.wrappedValue = string
        } else {
            self.wrappedValue = nil
        }
    }
}
