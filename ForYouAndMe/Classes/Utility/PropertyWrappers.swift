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
struct ExcludeInvalid<Element: Decodable>: Decodable {

    var wrappedValue: [Element]
    
    init(from decoder: Decoder) throws {

        var container = try decoder.unkeyedContainer()
        
        var elements = [Element]()
        if let count = container.count {
            elements.reserveCapacity(count)
        }

        while !container.isAtEnd {
            if let element = try container.decode(FailableDecodable<Element>.self).wrappedValue {
                elements.append(element)
            }
        }

        self.wrappedValue = elements
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
