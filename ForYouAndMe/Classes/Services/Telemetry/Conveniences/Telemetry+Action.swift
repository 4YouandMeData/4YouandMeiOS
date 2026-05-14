//
//  Telemetry+Action.swift
//  ForYouAndMe
//
//  State-mutating user actions. Add per-site call sites incrementally —
//  every payload key MUST appear in the "Always allowed" list in
//  docs/jam-telemetry.md.
//

import Foundation

extension Telemetry {
    public enum Action {

        /// Generic save-action emit. Use the stronger `save<Kind>(...)`
        /// helpers below where they exist.
        public static func save(kind: String,
                                noteId: String?,
                                extra: [String: AnyHashable] = [:],
                                file: String = #fileID,
                                function: String = #function,
                                line: UInt = #line) {
            var payload: [String: AnyHashable] = ["kind": kind]
            if let noteId = noteId { payload["noteId"] = noteId }
            for (k, v) in extra { payload[k] = v }
            track(TelemetryEvent(
                category: .action,
                name: "save",
                level: .info,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func submit(kind: String,
                                  extra: [String: AnyHashable] = [:],
                                  file: String = #fileID,
                                  function: String = #function,
                                  line: UInt = #line) {
            var payload: [String: AnyHashable] = ["kind": kind]
            for (k, v) in extra { payload[k] = v }
            track(TelemetryEvent(
                category: .action,
                name: "submit",
                level: .info,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func tap(kind: String,
                               extra: [String: AnyHashable] = [:],
                               file: String = #fileID,
                               function: String = #function,
                               line: UInt = #line) {
            var payload: [String: AnyHashable] = ["kind": kind]
            for (k, v) in extra { payload[k] = v }
            track(TelemetryEvent(
                category: .action,
                name: "tap",
                level: .info,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func auth(_ event: String,
                                method: String,
                                file: String = #fileID,
                                function: String = #function,
                                line: UInt = #line) {
            // event ∈ {"login.attempt","login.success","login.failure","logout","account.delete"}
            track(TelemetryEvent(
                category: .action,
                name: "auth.\(event)",
                level: .info,
                payload: ["method": method],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        // FUAM-3021. Opt-in permission-chain watchdog user actions — emitted
        // when the user taps Retry / Skip / Open Settings on the watchdog
        // alert. The trip itself is `error:permission.watchdog.tripped`
        // (Telemetry+Error).

        public static func permissionWatchdogRetry(branch: String,
                                                   attempt: Int,
                                                   file: String = #fileID,
                                                   function: String = #function,
                                                   line: UInt = #line) {
            track(TelemetryEvent(
                category: .action,
                name: "permission.watchdog.retry",
                level: .info,
                payload: ["branch": branch, "attempt": attempt],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func permissionWatchdogSkip(branch: String,
                                                  wasFirstAttempt: Bool,
                                                  file: String = #fileID,
                                                  function: String = #function,
                                                  line: UInt = #line) {
            track(TelemetryEvent(
                category: .action,
                name: "permission.watchdog.skip",
                level: .info,
                payload: ["branch": branch, "was_first_attempt": wasFirstAttempt],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

    }
}
