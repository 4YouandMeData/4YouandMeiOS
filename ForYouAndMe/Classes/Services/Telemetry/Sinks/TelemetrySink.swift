//
//  TelemetrySink.swift
//  ForYouAndMe
//
//  A sink receives every event the Telemetry facade publishes and
//  decides itself which ones to act on (using the event's category
//  and level). Keeping the protocol tiny makes future sinks trivial
//  to add (Mixpanel, Amplitude, Datadog, …).
//

import Foundation

public protocol TelemetrySink: AnyObject {
    func receive(_ event: TelemetryEvent)
}
