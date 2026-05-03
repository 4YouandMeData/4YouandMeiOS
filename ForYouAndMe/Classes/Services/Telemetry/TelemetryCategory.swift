//
//  TelemetryCategory.swift
//  ForYouAndMe
//
//  Coarse-grained category for a TelemetryEvent.
//  See `docs/jam-telemetry.md` for the full taxonomy.
//

import Foundation

public enum TelemetryCategory: String {
    case lifecycle
    case nav
    case action
    case net
    case error
    case perf
}
