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
        // FUAM-3021. Bridge the watchdog's high-value events to Firebase so
        // existing analytics dashboards can monitor the "how often does the
        // watchdog fire" and "skip vs retry" metrics. Retry and Open Settings
        // remain diagnostic-only (JamLog/Crashlytics) because they're
        // higher-volume and lower-signal.
        case "error:permission.watchdog.tripped":
            let branch = event.payload["branch"] as? String ?? ""
            let previousBranch = event.payload["previous_branch"] as? String
            let elapsedMs = event.payload["elapsed_ms"] as? Int ?? 0
            let attempt = event.payload["attempt"] as? Int ?? 0
            return .permissionWatchdogTimeout(branch: branch,
                                              previousBranch: previousBranch,
                                              elapsedMs: elapsedMs,
                                              attempt: attempt)
        case "action:permission.watchdog.skip":
            let branch = event.payload["branch"] as? String ?? ""
            let wasFirstAttempt = event.payload["was_first_attempt"] as? Bool ?? false
            return .permissionWatchdogSkipped(branch: branch,
                                              wasFirstAttempt: wasFirstAttempt)
        default:
            // Most Telemetry events are diagnostic-only and intentionally
            // NOT mirrored to Firebase Analytics. Existing AnalyticsEvent
            // call sites (consent agreed, screening completed, …) keep
            // calling AnalyticsService directly.
            return nil
        }
    }
}
