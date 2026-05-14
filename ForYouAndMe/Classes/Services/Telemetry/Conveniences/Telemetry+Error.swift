//
//  Telemetry+Error.swift
//  ForYouAndMe
//

import Foundation
import UIKit

extension Telemetry {
    public enum Errors {

        public static func handled(domain: String,
                                   underlying: Error?,
                                   file: String = #fileID,
                                   function: String = #function,
                                   line: UInt = #line) {
            var payload: [String: AnyHashable] = ["domain": domain]
            if let underlying = underlying {
                let ns = underlying as NSError
                payload["error_domain"] = ns.domain
                payload["error_code"] = ns.code
                payload["error_description"] = ns.localizedDescription
            }
            track(TelemetryEvent(
                category: .error,
                name: "handled",
                level: .error,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func reachabilityChanged(reachable: Bool,
                                               file: String = #fileID,
                                               function: String = #function,
                                               line: UInt = #line) {
            track(TelemetryEvent(
                category: .error,
                name: "reachability",
                level: reachable ? .info : .warn,
                payload: ["reachable": reachable],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func validation(form: String,
                                      field: String,
                                      rule: String,
                                      file: String = #fileID,
                                      function: String = #function,
                                      line: UInt = #line) {
            track(TelemetryEvent(
                category: .error,
                name: "validation",
                level: .warn,
                payload: ["form": form, "field": field, "rule": rule],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func permissionDenied(type: String,
                                            reason: String?,
                                            file: String = #fileID,
                                            function: String = #function,
                                            line: UInt = #line) {
            var payload: [String: AnyHashable] = ["type": type]
            if let reason = reason { payload["reason"] = reason }
            track(TelemetryEvent(
                category: .error,
                name: "permission.denied",
                level: .warn,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        // FUAM-3021. Opt-in permission-chain watchdog tripped — the per-branch
        // `Single<()>` did not emit within the active-time budget. The chain
        // cannot make progress; the coordinator dismisses the spinner and
        // surfaces a Retry/Skip alert.
        public static func permissionWatchdogTripped(branch: String,
                                                     previousBranch: String?,
                                                     elapsedMs: Int,
                                                     attempt: Int,
                                                     file: String = #fileID,
                                                     function: String = #function,
                                                     line: UInt = #line) {
            var payload: [String: AnyHashable] = [
                "branch": branch,
                "elapsed_ms": elapsedMs,
                "attempt": attempt,
                "host_app": Bundle.main.bundleIdentifier ?? "",
                "os_version": UIDevice.current.systemVersion
            ]
            if let previousBranch = previousBranch {
                payload["previous_branch"] = previousBranch
            }
            track(TelemetryEvent(
                category: .error,
                name: "permission.watchdog.tripped",
                level: .warn,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }
    }
}
