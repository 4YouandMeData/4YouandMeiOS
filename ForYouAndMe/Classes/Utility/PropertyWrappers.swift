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
struct FailableArrayExcludeInvalid<Element: Decodable>: Decodable {

    var wrappedValue: [Element]?
    
    init(from decoder: Decoder) throws {

        guard var container = try? decoder.unkeyedContainer(), false == (try? container.decodeNil()) else {
            self.wrappedValue = nil
            return
        }
        
        var elements = [Element]()
        if let count = container.count {
            elements.reserveCapacity(count)
        }

        while !container.isAtEnd {
            if let element = try container.decode(FailableDecodable<Element>.self).wrappedValue {
                elements.append(element)
            } else {
                print("Invalid item exclude from array")
            }
        }

        self.wrappedValue = elements
    }
}

@propertyWrapper
struct FailableArrayExcludeInvalidCodable<Element: Codable>: Codable {

    var wrappedValue: [Element]?
    
    init(from decoder: Decoder) throws {

        guard var container = try? decoder.unkeyedContainer(), false == (try? container.decodeNil()) else {
            self.wrappedValue = nil
            return
        }
        
        var elements = [Element]()
        if let count = container.count {
            elements.reserveCapacity(count)
        }

        while !container.isAtEnd {
            if let element = try container.decode(FailableDecodable<Element>.self).wrappedValue {
                elements.append(element)
            } else {
                print("Invalid item exclude from array")
            }
        }

        self.wrappedValue = elements
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.wrappedValue.encode(to: encoder)
    }
}

@propertyWrapper
struct FailableCodable<Wrapped: Codable>: Codable, OptionalCodingWrapper {
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
    
    public func encode(to encoder: Encoder) throws {
        try self.wrappedValue.encode(to: encoder)
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
            } else {
                print("Invalid item exclude from array")
            }
        }

        self.wrappedValue = elements
    }
}
    
@propertyWrapper
struct ExcludeInvalidCodable<Element: Codable>: Codable {
    
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
            } else {
                print("Invalid item exclude from array")
            }
        }
        
        self.wrappedValue = elements
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.wrappedValue.encode(to: encoder)
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

@propertyWrapper
struct ImageDecodable: Decodable, OptionalCodingWrapper {
    
    var wrappedValue: UIImage?
    
    init(wrappedValue: UIImage?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let data = try? container.decode(Data.self) {
            self.wrappedValue = UIImage(data: data)
        } else {
            self.wrappedValue = nil
        }
    }
}

@propertyWrapper
struct URLDecodable: Decodable, OptionalCodingWrapper {
    
    var wrappedValue: URL?
    
    init(wrappedValue: URL?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let urlString = try? container.decode(String.self) {
            self.wrappedValue = URL(string: urlString)
        } else {
            self.wrappedValue = nil
        }
    }
}

@propertyWrapper
struct ColorDecodable: Decodable, OptionalCodingWrapper {
    
    var wrappedValue: UIColor?
    
    init(wrappedValue: UIColor?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let colorString = try? container.decode(String.self) {
            self.wrappedValue = UIColor(hexString: colorString)
        } else {
            self.wrappedValue = nil
        }
    }
}

@propertyWrapper
struct EnumStringDecodable<T>: Decodable where T: RawRepresentable, T.RawValue == String {
    
    var wrappedValue: T
    
    init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dataString = try container.decode(String.self)
        guard let value = T(rawValue: dataString) else {
            throw EnumCodableError.invalidString
        }
        self.wrappedValue = value
    }
}

@propertyWrapper
struct FailableEnumStringDecodable<T>: Decodable, OptionalCodingWrapper where T: RawRepresentable, T.RawValue == String {
    
    var wrappedValue: T?
    
    init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dataString = try? container.decode(String.self) {
            self.wrappedValue = T(rawValue: dataString)
        } else {
            self.wrappedValue = nil
        }
    }
}

enum DateCodableError: Error {
    case invalidString
}

enum EnumCodableError: Error {
    case invalidString
}

public protocol DateValueCodableStrategy {
    associatedtype RawValue: Codable

    static func decode(_ value: RawValue) throws -> Date
    static func encode(_ date: Date) -> RawValue
}

@propertyWrapper
public struct DateValue<Formatter: DateValueCodableStrategy>: Codable {
    private let value: Formatter.RawValue
    public var wrappedValue: Date

    public init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
        self.value = Formatter.encode(wrappedValue)
    }
    
    public init(from decoder: Decoder) throws {
        self.value = try Formatter.RawValue(from: decoder)
        self.wrappedValue = try Formatter.decode(self.value)
    }
    
    public func encode(to encoder: Encoder) throws {
        try self.value.encode(to: encoder)
    }
}

@propertyWrapper
public struct FailableDateValue<Formatter: DateValueCodableStrategy>: Codable, OptionalCodingWrapper {
    private let value: Formatter.RawValue?
    public var wrappedValue: Date?

    public init(wrappedValue: Date?) {
        self.wrappedValue = wrappedValue
        if let wrappedValue = wrappedValue {
            self.value = Formatter.encode(wrappedValue)
        } else {
            self.value = nil
        }
    }
    
    public init(from decoder: Decoder) {
        self.value = try? Formatter.RawValue(from: decoder)
        if let value = self.value {
            self.wrappedValue = try? Formatter.decode(value)
        } else {
            self.wrappedValue = nil
        }
    }
    
    public func encode(to encoder: Encoder) {
        try? self.value?.encode(to: encoder)
    }
}

public struct ISO8601Strategy: DateValueCodableStrategy {
    static let dateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter
    }()
    
    public static func decode(_ value: String) throws -> Date {
        guard let date = Self.dateFormatter.date(from: value) else {
            throw DateCodableError.invalidString
        }
        return date
    }
    
    public static func encode(_ date: Date) -> String {
        return Self.dateFormatter.string(from: date)
    }
}

public struct DateStrategy: DateValueCodableStrategy {
    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormatter
    }()
    
    public static func decode(_ value: String) throws -> Date {
        guard let date = Self.dateFormatter.date(from: value) else {
            throw DateCodableError.invalidString
        }
        return date
    }
    
    public static func encode(_ date: Date) -> String {
        return Self.dateFormatter.string(from: date)
    }
}

@propertyWrapper
struct TimeZoneCodable: Codable, OptionalCodingWrapper {
    
    var wrappedValue: TimeZone?
    
    init(wrappedValue: TimeZone?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let timeZoneIdentifier = try? container.decode(String.self) {
            self.wrappedValue = TimeZone(identifier: timeZoneIdentifier)
        } else {
            self.wrappedValue = nil
        }
    }
}

@propertyWrapper
struct StringToInt: Decodable, OptionalCodingWrapper {
    
    var wrappedValue: Int?
    
    init(wrappedValue: Int?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self), let doubleValue = Double(string) {
            self.wrappedValue = Int(doubleValue)
        } else {
            self.wrappedValue = nil
        }
    }
}
