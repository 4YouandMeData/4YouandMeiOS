//
//  JamLogSink.swift
//  ForYouAndMe
//
//  Routes every TelemetryEvent into FYAMLog (which fans to os.Logger
//  + JamLog). Pretty-prints the payload as a sortable, scannable line
//  for Jam recordings.
//

import Foundation

final class JamLogSink: TelemetrySink {

    func receive(_ event: TelemetryEvent) {
        let line = format(event)
        let trace = event.trace
        let file = trace?.file ?? #fileID
        let function = trace?.function ?? #function
        let lineNo = trace?.line ?? 0

        switch event.level {
        case .debug:
            FYAMLog.debug(line, file: file, function: function, line: lineNo)
        case .info:
            FYAMLog.info(line, file: file, function: function, line: lineNo)
        case .warn:
            FYAMLog.warn(line, file: file, function: function, line: lineNo)
        case .error:
            FYAMLog.error(line, file: file, function: function, line: lineNo)
        }
    }

    private func format(_ event: TelemetryEvent) -> String {
        if event.payload.isEmpty {
            return event.fullName
        }
        // Stable key order so log lines diff cleanly between recordings.
        let keys = event.payload.keys.sorted()
        let parts = keys.map { key -> String in
            let value = event.payload[key].map { "\($0)" } ?? "nil"
            return "\(key)=\(value)"
        }
        return "\(event.fullName) \(parts.joined(separator: " "))"
    }
}
