//
//  Date+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

public let dateTimeFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
public let dateDataPointFormat = "yyyy-MM-dd HH:mm"
public let dateFormat = "yyyy-MM-dd"
public let timeFormat = "hh:mm a"
public let utc = "UTC"
public let dayTime = "HH"
public let dayShort = "EEE"
public let monthShort = "MMM d"
public let yearShortDate = "MMM yy"
public let literalDate = "MMMM dd yyyy"

public extension Date {
    /// Formats the date with an arbitrary `DateFormatter` pattern.
    ///
    /// - Warning: DISPLAY ONLY. When no `locale` is passed this inherits the
    ///   device locale, and iOS rewrites `HH:mm:ss` patterns into `h:mm:ss a`
    ///   under the 12-hour-clock setting — which corrupted server-bound
    ///   datetimes (FUAM-3522). NEVER use the output of this method for a value
    ///   sent to the backend. For any server-bound datetime use
    ///   `Date.utcDateTimeString()` / `ApiDateFormatter.string(from:)`, which
    ///   are locale- and 12-hour-clock-immune by construction.
    func string(withFormat format: String, timeZone: TimeZone? = nil, locale: Locale? = nil) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        if let timeZone = timeZone {
            dateFormatter.timeZone = timeZone
        }
        if let locale = locale {
            dateFormatter.locale = locale
        }
        return dateFormatter.string(from: self)
    }

    /// Serializes the date for API bodies as true-UTC ISO 8601
    /// (`yyyy-MM-dd'T'HH:mm:ss'Z'`).
    ///
    /// This is the sanctioned convenience entry point for server-bound
    /// datetimes; it delegates to `ApiDateFormatter`, which is backed by
    /// `ISO8601DateFormatter` and is therefore immune to the device locale and
    /// the 12-hour-clock setting (FUAM-3522). The output is byte-identical to
    /// the previous `dateTimeFormat`-based serialization in UTC.
    func utcDateTimeString() -> String {
        ApiDateFormatter.string(from: self)
    }
    
    static func currentDateInMilliSeconds() -> Double {
        return round(Date().timeIntervalSince1970 * 1000)
    }
    
    func getDate(for days: Int) -> Date {
        let date = Calendar.current.date(byAdding: .day, value: days, to: self)
        return date ?? Date()
    }
    
    func getDates(for days: Int, interval: Int, format: String = dayShort) -> [String] {
        var arrayOfDates = [String]()
        arrayOfDates.append(self.string(withFormat: format))
        for index in 1...interval {
            arrayOfDates.append(self.getDate(for: (-index * days)).string(withFormat: format))
        }
        return arrayOfDates.reversed()
    }

    func getSecondsSinceMidnight() -> Int {
        let calendar = Calendar.current
        return (calendar.component(.hour, from: self) * 3600 + calendar.component(.minute, from: self) * 60)
    }
}

public extension String {
    func date(withFormat format: String, timeZone: TimeZone? = nil, locale: Locale? = nil) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        if let timeZone = timeZone {
            dateFormatter.timeZone = timeZone
        }
        if let locale = locale {
            dateFormatter.locale = locale
        }
        return dateFormatter.date(from: self)
    }
}

public extension Int {
    func dateFromSeconds() -> Date {
        let calendar = Calendar.current
        let currentDate = Date()
        let startDayDate = calendar.startOfDay(for: currentDate)
        let date = Date(timeInterval: TimeInterval(self), since: startDayDate)
        return date
     }
}
