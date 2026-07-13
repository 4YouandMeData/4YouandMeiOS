//
//  ApiDateFormatter.swift
//  ForYouAndMe
//
//  Created for FUAM-3522 — locale-immune datetime serialization for API bodies.
//  Copyright © 2026 Balzo srl. All rights reserved.
//

import Foundation

/// The single, locale- and 12-hour-clock-immune serializer for every
/// server-bound datetime string emitted by the framework.
///
/// # Why this exists
/// `Date.string(withFormat:)` builds a `DateFormatter` and, when no explicit
/// locale is passed, inherits the device locale. iOS then rewrites a
/// `HH:mm:ss` pattern into `h:mm:ss a` whenever the user forces the 12-hour
/// clock in *Settings → General → Date & Time → 24-Hour Time (off)*. That
/// produced real production payloads such as `"2026-07-02T4:58:50 pmZ"`, which
/// the backend read 12 hours off (FUAM-3522 / prior FUAM-3469 UTC fix).
///
/// `ISO8601DateFormatter` has no `dateFormat` string to be rewritten and does
/// not consult the device locale or the 12-hour setting, so it is immune by
/// construction. Its `.withInternetDateTime` option emits exactly the wire
/// format the backend expects — whole seconds, a literal `Z`, no fractional
/// seconds: `yyyy-MM-dd'T'HH:mm:ss'Z'`.
///
/// # Wire contract
/// Output is byte-identical to the previously-healthy `utcDateTimeString()`
/// output (`2026-06-23T20:03:00Z`). Do not add fractional seconds or change the
/// timezone designator without a coordinated backend change.
public enum ApiDateFormatter {

    /// Shared, thread-safe serializer for server-bound datetimes.
    ///
    /// `ISO8601DateFormatter` is thread-safe for concurrent reads once
    /// configured (Apple documents its formatting methods as safe to call from
    /// multiple threads), so a single shared instance is used. It is configured
    /// once, up front, and never mutated afterwards.
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        // .withInternetDateTime => yyyy-MM-dd'T'HH:mm:ssZ, in UTC ('Z'),
        // whole seconds, no fractional part. Explicitly UTC so the literal 'Z'
        // is always correct.
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// Serializes `date` as a true-UTC ISO 8601 string for API bodies:
    /// `yyyy-MM-dd'T'HH:mm:ss'Z'`.
    ///
    /// This is the only sanctioned path for server-bound datetime values. It is
    /// immune to the device locale and the 12-hour-clock setting.
    public static func string(from date: Date) -> String {
        return self.iso8601.string(from: date)
    }
}
