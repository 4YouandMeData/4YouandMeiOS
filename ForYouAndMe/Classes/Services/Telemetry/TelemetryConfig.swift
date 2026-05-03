//
//  TelemetryConfig.swift
//  ForYouAndMe
//
//  Process-wide telemetry configuration set by `FYAMManager.startup(...)`
//  and read by `NetworkApiGateway` when it builds its plugin chain.
//

import Foundation

enum TelemetryConfig {
    /// How much HTTP body data the TelemetryPlugin captures. Defaults to
    /// `.truncated` (request ≤ 1 KB, response ≤ 4 KB on 2xx, full on
    /// non-2xx; all redacted). Sensitive endpoints always suppress
    /// regardless.
    static var networkBodyCaptureMode: NetworkBodyCaptureMode = .truncated
}
