//
//  TelemetryTrace.swift
//  ForYouAndMe
//
//  Auto-captured call-site trace. Mirrors JamLog's LogMessage.Trace shape.
//

import Foundation

public struct TelemetryTrace: Equatable {
    public let file: String
    public let function: String
    public let line: UInt

    public init(file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.file = file
        self.function = function
        self.line = line
    }
}
