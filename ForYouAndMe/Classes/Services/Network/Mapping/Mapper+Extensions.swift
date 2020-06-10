//
//  Mapper+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Mapper

extension Optional where Wrapped == String {
    public var nilIfEmpty: String? {
        return (self ?? "").isEmpty ? nil : self
    }
}

extension Mapper {
    public func from(_ field: String) throws -> Date {
        let dateStr: String = try self.from(field)
        
        let dateFormatter = ISO8601DateFormatter()
        
        // Attempt to interpret the date string without AND with fractional seconds. If both attempts fail, it throws parsing exceptions
        dateFormatter.formatOptions = [.withInternetDateTime]
        if let date = dateFormatter.date(from: dateStr) {
            return date
        }
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: dateStr) {
            return date
        }
        throw MapperError.customError(field: field, message: "'\(dateStr)' is not a valid date for the given date format")
    }
    
    public func optionalFrom(_ field: String) -> Date? {
        guard let dateStr: String = self.optionalFrom(field) else {
            return nil
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        // Attempt to interpret the date string without AND with fractional seconds. If both attempts fail, it throws parsing exceptions
        dateFormatter.formatOptions = [.withInternetDateTime]
        if let date = dateFormatter.date(from: dateStr) {
            return date
        }
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: dateStr) {
            return date
        }
        return nil
    }
    
    public func from(_ field: String, dateFormat: String) throws -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        return try self.from(field, dateFormatter: dateFormatter)
    }
    
    public func from(_ field: String, utcDateFormat: String) throws -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = utcDateFormat
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return try self.from(field, dateFormatter: dateFormatter)
    }
    
    public func optionalFrom(_ field: String, dateFormat: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        return self.optionalFrom(field, dateFormatter: dateFormatter)
    }
    
    public func optionalFrom(_ field: String, utcDateFormat: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = utcDateFormat
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return self.optionalFrom(field, dateFormatter: dateFormatter)
    }
    
    public func from(_ field: String, dateFormatter: DateFormatter) throws -> Date {
        let dateStr: String = try self.from(field)
        if let date = dateFormatter.date(from: dateStr) {
            return date
        }
        throw MapperError.customError(field: field, message: "'\(dateStr)' is not a valid date for the given date format")
    }
    
    public func optionalFrom(_ field: String, dateFormatter: DateFormatter) -> Date? {
        let dateStr: String? = self.optionalFrom(field)
        if let dateStr = dateStr, let date = dateFormatter.date(from: dateStr) {
            return date
        }
        return nil
    }
    
    public func optionalFrom(_ field: String, nilIfEmpty: Bool) -> String? {
        let string: String? = self.optionalFrom(field)
        if let string = string, (!nilIfEmpty || !string.isEmpty) {
            return string
        }
        return nil
    }
    
    static public func excludeInvalid<T>(object: Any?) throws -> [T] where T: Mappable {
        guard let list = object as? [NSDictionary] else {
            throw MapperError.customError(field: nil, message: "Unexpected value. Expected array of dictionaries")
        }
        
        var array: [T] = []
        for item in list {
            if let item = try? T.init(map: Mapper(JSON: item)) {
                array.append(item)
            } else {
                debugPrint("Invalid item found in array: Excluded")
            }
        }
        
        return array
    }
    
    static public func errorIfEmpty<T>(object: Any?) throws -> [T] {
        guard let list = object as? [T] else {
            throw MapperError.customError(field: nil, message: "Unexpected value. Expected array")
        }
        guard list.isEmpty == false else {
            throw MapperError.customError(field: nil, message: "Unexpected empty array")
        }
        return list
    }
}
