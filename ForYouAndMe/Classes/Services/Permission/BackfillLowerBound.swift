//
//  BackfillLowerBound.swift
//  ForYouAndMe
//
//  FUAM-3945: the single backfill lower-bound policy shared by HealthKit and SensorKit.
//

import Foundation

/// How far back a health/sensor backfill may reach, and why (FUAM-3945).
///
/// The rule, identical for both subsystems:
/// ```
/// joinDay    = start of the participant's study-entry day, in the participant's timezone
///              (derived from the backend's `days_in_study`), or nil when it cannot be established
/// hardCap    = now − 365 days
/// lowerBound = joinDay == nil ? now : max(joinDay, hardCap)
/// ```
/// Two invariants follow, and neither may be relaxed by a caller:
/// 1. nothing measured before the participant's join day is ever transmitted — the HealthKit and
///    SensorKit stores are device-wide and survive reinstalls, so the same OS store can hold data
///    belonging to a different participant or to an earlier enrolment;
/// 2. nothing older than 365 days is ever transmitted, whatever the join day says.
///
/// When the join day cannot be established, collection is **forward-only** (`lowerBound == now`):
/// "we could not establish consent" must never mean "upload some history". There is deliberately no
/// legacy-window fallback and no dependency on the host consent-bypass flags
/// (`FYAMHealthKitIgnoreOptInConsent` / `FYAMSensorKitIgnoreOptInConsent`), which cannot widen this
/// bound. This supersedes FUAM-3841's `retentionFloor`, whose `max(joinDay, now − 7d)` capped every
/// already-enrolled participant's reach at 7 days.
struct BackfillLowerBound {

    /// `bounded_by` vocabulary of the `sensor_data_backfill_reach` analytics event.
    enum Origin: String {
        /// The bound is the participant's join day.
        case joinDate = "join_date"
        /// The join day is older than 365 days: the bound is the 365-day hard cap.
        case hardCap365d = "hard_cap_365d"
        /// No join day could be established: forward-only, no history at all.
        case forwardOnly = "forward_only"
        /// A local cursor ahead of the bound moved the window start (routine resume, not a backfill).
        case cursor
        /// The plan resolved to no window at all (e.g. enrolled today, still inside the embargo).
        case emptyPlan = "empty_plan"
        /// A window was forfeited after repeated fetch failures (data loss trace).
        case gaveUp = "gave_up"
    }

    /// Absolute maximum reach into the past, regardless of the join day.
    static let hardCap: TimeInterval = 365 * 24 * 60 * 60

    let date: Date
    let origin: Origin

    /// `true` when no join day was available, so no historical data may be collected.
    var isForwardOnly: Bool { self.origin == .forwardOnly }

    /// Resolve the lower bound. `joinDay` is the study join day (start of day in the participant's
    /// timezone); pass `nil` whenever it cannot be established — including a `days_in_study <= 0`
    /// user record or no user at all.
    static func resolve(joinDay: Date?, now: Date = Date()) -> BackfillLowerBound {
        guard let joinDay = joinDay else {
            return BackfillLowerBound(date: now, origin: .forwardOnly)
        }
        let hardCapDate = now.addingTimeInterval(-Self.hardCap)
        return joinDay >= hardCapDate
            ? BackfillLowerBound(date: joinDay, origin: .joinDate)
            : BackfillLowerBound(date: hardCapDate, origin: .hardCap365d)
    }
}
