//
//  Telemetry.swift
//  ForYouAndMe
//
//  The single emit-API for events flowing out of the framework. Fans
//  out to all registered sinks (JamLog, AnalyticsService, Crashlytics,
//  and any host-app-registered sinks for Mixpanel/Amplitude/etc.).
//
//  Every payload passes through `Redactor.scrub` before reaching any
//  sink, so call sites can't accidentally leak secrets.
//
//  See: docs/jam-telemetry.md
//

import Foundation

public enum Telemetry {

    // MARK: - Sink registry

    private static var sinks: [TelemetrySink] = []
    private static let lock = NSLock()

    /// Replace the entire sink set. Called once at startup from
    /// `Services.setup(...)`. Host apps that need a custom set can also
    /// call this directly with their own sinks.
    public static func setSinks(_ newSinks: [TelemetrySink]) {
        lock.lock(); defer { lock.unlock() }
        sinks = newSinks
    }

    /// Append a sink (e.g. host app registers a Mixpanel sink at boot).
    public static func register(_ sink: TelemetrySink) {
        lock.lock(); defer { lock.unlock() }
        sinks.append(sink)
    }

    /// Reset to no sinks. Test helper — not used in production paths.
    static func resetForTesting() {
        lock.lock(); defer { lock.unlock() }
        sinks.removeAll()
    }

    // MARK: - Emit

    /// Primary emit-API. Use the convenience namespaces (Telemetry.nav,
    /// Telemetry.net, etc.) instead of constructing TelemetryEvent
    /// directly when possible — they enforce redaction by construction.
    public static func track(_ event: TelemetryEvent) {
        let scrubbed = TelemetryEvent(
            category: event.category,
            name: event.name,
            level: event.level,
            payload: Redactor.scrub(event.payload),
            trace: event.trace
        )
        let snapshot: [TelemetrySink] = {
            lock.lock(); defer { lock.unlock() }
            return sinks
        }()
        for sink in snapshot {
            sink.receive(scrubbed)
        }
    }

    /// Convenience for ad-hoc events. Prefer the typed builders.
    public static func track(_ category: TelemetryCategory,
                             _ name: String,
                             level: TelemetryLevel = .info,
                             payload: [String: AnyHashable] = [:],
                             file: String = #fileID,
                             function: String = #function,
                             line: UInt = #line) {
        let event = TelemetryEvent(
            category: category,
            name: name,
            level: level,
            payload: payload,
            trace: TelemetryTrace(file: file, function: function, line: line)
        )
        track(event)
    }
}
