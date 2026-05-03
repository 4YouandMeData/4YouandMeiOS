//
//  Telemetry+Lifecycle.swift
//  ForYouAndMe
//

import Foundation

extension Telemetry {
    public enum lifecycle {

        public static func frameworkStart(podVersion: String,
                                          hostBundleId: String?,
                                          file: String = #fileID,
                                          function: String = #function,
                                          line: UInt = #line) {
            let payload: [String: AnyHashable] = [
                "podVersion": podVersion,
                "hostBundleId": hostBundleId ?? "unknown"
            ]
            track(TelemetryEvent(
                category: .lifecycle,
                name: "framework.start",
                level: .info,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func userSessionStart(userId: String,
                                            file: String = #fileID,
                                            function: String = #function,
                                            line: UInt = #line) {
            track(TelemetryEvent(
                category: .lifecycle,
                name: "user.session.start",
                level: .info,
                payload: ["userId": userId],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func userSessionEnd(userId: String?,
                                          reason: String,
                                          file: String = #fileID,
                                          function: String = #function,
                                          line: UInt = #line) {
            var payload: [String: AnyHashable] = ["reason": reason]
            if let userId = userId { payload["userId"] = userId }
            track(TelemetryEvent(
                category: .lifecycle,
                name: "user.session.end",
                level: .info,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }
    }
}
