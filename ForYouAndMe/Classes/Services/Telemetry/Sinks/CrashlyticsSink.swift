//
//  CrashlyticsSink.swift
//  ForYouAndMe
//
//  Mirrors `error:*` Telemetry events into Firebase Crashlytics as
//  non-fatal records, so error lines show up alongside crashes in
//  the Crashlytics dashboard.
//
//  Existing `AnalyticsService.serverError` / `healthError` paths
//  already write to Crashlytics directly via
//  `FirebaseAnalyticsPlatform.reportNonFatalError` — those keep
//  working. This sink covers the broader `error:` taxonomy added by
//  the Telemetry layer.
//

import Foundation
import FirebaseCrashlytics

final class CrashlyticsSink: TelemetrySink {

    func receive(_ event: TelemetryEvent) {
        guard event.level == .error else { return }

        // Build a minimal NSError that Crashlytics groups by domain+code.
        // The user-info dict carries the redacted payload — Crashlytics
        // shows it under "Custom Keys".
        let domain = "fyam.\(event.fullName)"
        var userInfo: [String: Any] = [:]
        for (k, v) in event.payload { userInfo[k] = v }
        if let trace = event.trace {
            userInfo["fyam_trace"] = "\(trace.file):\(trace.line) \(trace.function)"
        }
        let nsError = NSError(domain: domain, code: 0, userInfo: userInfo)
        Crashlytics.crashlytics().record(error: nsError)
    }
}
