//
//  TelemetryEvent.swift
//  ForYouAndMe
//
//  The unit of work the Telemetry facade ships to its sinks.
//  Constructed by callers via the convenience namespaces in
//  Telemetry+<Category>.swift — direct construction is allowed but
//  discouraged because the convenience builders enforce redaction.
//

import Foundation

public struct TelemetryEvent {

    public let category: TelemetryCategory
    public let name: String
    public let level: TelemetryLevel
    public let payload: [String: AnyHashable]
    public let trace: TelemetryTrace?

    public init(category: TelemetryCategory,
                name: String,
                level: TelemetryLevel,
                payload: [String: AnyHashable] = [:],
                trace: TelemetryTrace? = nil) {
        self.category = category
        self.name = name
        self.level = level
        self.payload = payload
        self.trace = trace
    }

    /// Stable string key, e.g. `"net:request"`, `"nav:tab.switch"`.
    public var fullName: String {
        "\(category.rawValue):\(name)"
    }
}
