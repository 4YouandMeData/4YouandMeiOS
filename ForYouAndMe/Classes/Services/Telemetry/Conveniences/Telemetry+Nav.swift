//
//  Telemetry+Nav.swift
//  ForYouAndMe
//

import Foundation

extension Telemetry {
    public enum Nav {

        public static func appear(screen: String,
                                  className: String,
                                  file: String = #fileID,
                                  function: String = #function,
                                  line: UInt = #line) {
            track(TelemetryEvent(
                category: .nav,
                name: "appear",
                level: .info,
                payload: ["screen": screen, "class": className],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func disappear(screen: String,
                                     className: String,
                                     file: String = #fileID,
                                     function: String = #function,
                                     line: UInt = #line) {
            track(TelemetryEvent(
                category: .nav,
                name: "disappear",
                level: .debug,
                payload: ["screen": screen, "class": className],
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func tabSwitch(from: String?,
                                     to: String,
                                     file: String = #fileID,
                                     function: String = #function,
                                     line: UInt = #line) {
            var payload: [String: AnyHashable] = ["to": to]
            if let from = from { payload["from"] = from }
            track(TelemetryEvent(
                category: .nav,
                name: "tab.switch",
                level: .info,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }
    }
}
