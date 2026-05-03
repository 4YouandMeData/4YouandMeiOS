//
//  AnalyticsServiceSink.swift
//  ForYouAndMe
//
//  Bridges new Telemetry events into the existing AnalyticsService
//  (and therefore Firebase Analytics + Crashlytics). Only events that
//  have an existing AnalyticsEvent equivalent are forwarded — the
//  Telemetry layer is otherwise diagnostic and shouldn't pollute
//  Firebase Analytics dashboards with new event names.
//
//  Adding a new bridged event: add a case in the switch below mapping
//  the new TelemetryEvent.fullName to the corresponding AnalyticsEvent.
//

import Foundation

final class AnalyticsServiceSink: TelemetrySink {

    private let analytics: AnalyticsService

    init(analytics: AnalyticsService) {
        self.analytics = analytics
    }

    func receive(_ event: TelemetryEvent) {
        guard let mapped = mapToAnalyticsEvent(event) else { return }
        analytics.track(event: mapped)
    }

    private func mapToAnalyticsEvent(_ event: TelemetryEvent) -> AnalyticsEvent? {
        switch event.fullName {
        case "nav:tab.switch":
            // Firebase tab-switch event uses the destination tab name.
            if let to = event.payload["to"] as? String {
                return .switchTab(to)
            }
            return nil
        case "nav:appear":
            // Mirrors what existing call sites of `.recordScreen` do.
            if let screen = event.payload["screen"] as? String,
               let cls = event.payload["class"] as? String {
                return .recordScreen(screenName: screen, screenClass: cls)
            }
            return nil
        default:
            // Most Telemetry events are diagnostic-only and intentionally
            // NOT mirrored to Firebase Analytics. Existing AnalyticsEvent
            // call sites (consent agreed, screening completed, …) keep
            // calling AnalyticsService directly.
            return nil
        }
    }
}
