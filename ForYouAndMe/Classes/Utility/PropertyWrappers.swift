//
//  PropertyWrappers.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

// MARK: - OptionalCodingWrapper

/// Protocol for a PropertyWrapper to properly handle Coding when the wrappedValue is Optional
public protocol OptionalCodingWrapper {
    associatedtype WrappedType: ExpressibleByNilLiteral
    var wrappedValue: WrappedType { get }
    init(wrappedValue: WrappedType)
}

extension KeyedDecodingContainer {
    // This is used to override the default decoding behavior for OptionalCodingWrapper to allow a value to avoid a missing key Error
    public func decode<T>(_ type: T.Type,
                          forKey key: KeyedDecodingContainer<K>.Key) throws -> T where T: Decodable, T: OptionalCodingWrapper {
        return try decodeIfPresent(T.self, forKey: key) ?? T(wrappedValue: nil)
    }
}

// MARK: - Property Wrappers

@propertyWrapper
struct FailableDecodable<Wrapped: Decodable>: Decodable, OptionalCodingWrapper {
    var wrappedValue: Wrapped?
    
    init(wrappedValue: Wrapped?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(), false == container.decodeNil() {
            self.wrappedValue = try? container.decode(Wrapped.self)
        } else {
            self.wrappedValue = nil
        }
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
struct NilIfEmptyString: Decodable, OptionalCodingWrapper {
    
    var wrappedValue: String?
    
    init(wrappedValue: String?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self), false == string.isEmpty {
            self.wrappedValue = string
        } else {
            self.wrappedValue = nil
        }
    }
}
