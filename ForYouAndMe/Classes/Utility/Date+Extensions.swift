//
//  Date+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

public extension Date {
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
    
    static func currentDateInMilliSeconds() -> Double {
        return round(Date().timeIntervalSince1970 * 1000)
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
