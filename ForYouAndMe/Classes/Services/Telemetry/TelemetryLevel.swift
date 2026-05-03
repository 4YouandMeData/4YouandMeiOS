//
//  TelemetryLevel.swift
//  ForYouAndMe
//

import Foundation

public enum TelemetryLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warn = 2
    case error = 3

    public static func < (lhs: TelemetryLevel, rhs: TelemetryLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
