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
        /// A window was forfeited after repeated fetch failures, or because even a floor-sized
        /// sub-window is over the server's payload cap (data loss trace).
        case gaveUp = "gave_up"
        /// A HealthKit chunk was over the payload cap and its TIME window was halved (FUAM-3945).
        case bisected
        /// One HealthKit chunk burned its attempt budget: the data type was left for the next
        /// sequence with its cursor untouched (a stall, not data loss — yet).
        case attemptsExhausted = "attempts_exhausted"
        /// The drain-time consent gate dropped records from an already-queued batch (data loss
        /// trace: in steady state this should never fire, so any volume at all is actionable).
        case drainFiltered = "drain_filtered"
        /// The stored cursor sat further in the future than any clock could legitimately have
        /// written it (an offline forward clock excursion), so it was RESET to the consent bound
        /// and the range it skipped is being re-walked. `reachedBack` carries the corrupt cursor,
        /// so the size of the gap that was recovered is readable in Firebase (FUAM-3964, F1).
        case futureCursor = "future_cursor"
        /// A fetched window's records could not be PERSISTED to the upload queue (FUAM-3945,
        /// AC4): the cursor was left in place so the window is retried, and after the attempt
        /// budget it is abandoned via `gave_up`. Any volume here is actionable.
        case enqueueFailed = "enqueue_failed"
        /// A HealthKit payload was split proactively at the 8 MB safety margin BEFORE any server
        /// rejection (FUAM-3945, AC5). Reactive `bisected` stays as the backstop trace.
        case proactiveSplit = "proactive_split"
        /// A queued batch the server PERMANENTLY rejected (the 4xx validation class — see
        /// `SensorUploadError`) exhausted its upload budget and was dropped from the persisted
        /// queue (FUAM-3945 round 5, AC6): `reachedBack` carries the batch's window start, so
        /// the age of the lost data is readable in Firebase. Any volume here is actionable.
        case uploadStuck = "upload_stuck"
        /// A backward probe buffered more records than `probeBufferMaxRecords` while discovering
        /// the retention horizon: the buffered windows were flushed early and the rest of the
        /// probe enqueued as-you-go — correct, but no longer strictly chronological (FUAM-3945
        /// round 4). `reachedBack` carries the window that tripped the cap.
        case probeBufferOverflow = "probe_buffer_overflow"
    }

    /// How far a stored cursor may sit above the capped planning upper bound before it is treated
    /// as corrupt rather than merely recent. One UTC day: a cursor legitimately parked at the end
    /// of the last complete day must never trip the reset (FUAM-3964, F1).
    static let futureCursorTolerance: TimeInterval = 24 * 60 * 60

    /// `true` when `cursor` is provably not something a sane clock wrote: it exceeds `upperBound`
    /// — already capped at `min(deviceNow, serverNow)`, minus any embargo — by more than
    /// `futureCursorTolerance`.
    ///
    /// This is the ONE case in which a cursor may be rewound. The rule everywhere else is
    /// "cursors only move forward", because rewinding re-uploads data and, worse, can re-open a
    /// window the participant has since withdrawn consent for. Neither applies here: the rewind
    /// target is the consent bound itself (never below it), and every window is a whole UTC day,
    /// so a re-walk reproduces the exact same anchors and the backend union-merges the re-upload
    /// instead of duplicating it. Bandwidth is the only cost, against the alternative of silently
    /// never fetching the interval between the excursion and the burnt cursor.
    static func isFutureBurned(cursor: Date?, upperBound: Date) -> Bool {
        guard let cursor = cursor else { return false }
        return cursor > upperBound.addingTimeInterval(Self.futureCursorTolerance)
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

// MARK: - HealthKit query bounds

/// The HealthKit query bounds for one data type, derived from the shared lower bound and that
/// type's stored cursor (FUAM-3945 review fix #6). Pure, so the three enforcement points are
/// unit-testable without a HealthKit runtime.
struct HealthBackfillQuery: Equatable {
    /// Where the chunked walk starts: the stored cursor, never allowed below the bound.
    let startDate: Date
    /// The per-sample consent gate handed to `HealthSampleUploader.run`. Always the bound
    /// itself — never the cursor, never `nil`: filtering must not be opt-in.
    let minimumSampleDate: Date
}

extension BackfillLowerBound {

    /// The query bounds for a HealthKit data type, or `nil` when the type must be SKIPPED —
    /// forward-only, i.e. the join day could not be established. The caller must then leave the
    /// stored cursor untouched, so the real backfill still runs once the join day resolves.
    func healthQuery(storedCursor: Date?) -> HealthBackfillQuery? {
        guard !self.isForwardOnly else { return nil }
        return HealthBackfillQuery(startDate: Swift.max(storedCursor ?? self.date, self.date),
                                   minimumSampleDate: self.date)
    }
}

// MARK: - Server clock

/// The trusted clock: the backend's, not the device's (FUAM-3964).
///
/// Every backend response carries a standard HTTP `Date` header. `NetworkApiGateway` feeds it to
/// `record(headerDate:)` on every successful response and we keep `offset = serverTime −
/// deviceTime` in `UserDefaults`, so `ServerClock.now` is available offline and at launch, before
/// any request has completed. With no offset ever stored (first launch on a fresh install, still
/// offline) it degrades to `Date()` — today's behaviour.
///
/// This supersedes `BackfillClock`, the monotonic high-water mark of observed wall-clock time.
/// That mark protected the join-day derivation against a clock rolled BACKWARDS, but a clock
/// rolled FORWARDS then pinned the bound in the future and suspended collection until real time
/// caught up. A server-anchored clock removes both directions at once.
///
/// Three uses, and only these three:
/// 1. the join-day derivation in `RepositoryImpl.enrollmentDate` — moving the device clock no
///    longer moves the participant's join day, in either direction;
/// 2. a CAP on the planning UPPER bound in both subsystems (`min(deviceNow, ServerClock.now)`),
///    so a device clock ahead cannot plan a window — and therefore cannot write a cursor —
///    beyond server time;
/// 3. the clock the 365-day hard cap below is measured from, resolved the other way round,
///    `max(deviceNow, ServerClock.now)` (review I1): the cap is a LOWER bound, so the LATER of
///    the two clocks is the safe one — it can only ever tighten the reach, while the raw device
///    clock rolled back by Δ would let the reach grow to 365 + Δ real days.
///
/// **How much protection this actually is.** All of it depends on an offset having been RECORDED
/// while the clock was wrong — i.e. on at least one backend response observed under the wrong
/// clock. Until then `storedOffset` is `nil` (or stale from when the clock was right),
/// `ServerClock.now()` degrades to `Date()`, and the whole pipeline — plan, fetch, enqueue and
/// cursor write — proceeds on the device clock, uncapped. A device that goes offline, has its
/// clock moved, and syncs while still offline is therefore NOT protected for that excursion. The
/// MACHINERY recovers on the first response afterwards, and a cursor the excursion burnt into the
/// future is detected at plan time and reset to the consent bound (`isFutureBurned`, reported as
/// `future_cursor`) so the skipped range is re-fetched — what is never repaired is a measurement
/// timestamp the OS recorded under the wrong clock. That offline window is the accepted residual:
/// gating collection on "have we heard from the server recently" would stop collecting for every
/// participant in a tunnel to protect against a rare one with a wrong clock. There is
/// deliberately no offline gate.
///
/// Fetch requests to the OS keep using device wall-clock: HealthKit and SensorKit index their
/// stores with the same (possibly wrong) clock that wrote the samples, so translating query
/// bounds into server time would just miss data. Only PLANNING is capped.
///
/// What this does NOT fix: a measurement timestamp the OS recorded under a wrong clock is wrong
/// for ever. The consent filter and the backend's future-anchor plausibility check are the guards
/// there; server time fixes the machinery (bounds, cursor), not the historical samples.
enum ServerClock {

    static let storageKey = "serverClock.offset"

    /// Only rewrite the stored offset when it moves by more than this. Every API response would
    /// otherwise be a `UserDefaults` write, and the offset is only ever read at day granularity;
    /// this also absorbs the network-latency bias baked into every measurement (the `Date` header
    /// is stamped when the response is generated, we read the clock when it arrives).
    static let persistenceGranularity: TimeInterval = 5

    /// Beyond this much divergence, the device clock is not drifting, it is wrong.
    static let aheadReportThreshold: TimeInterval = 24 * 60 * 60

    /// Serialises the once-per-launch latch below. `ServerClock.now` is called from the HealthKit
    /// upload queue, the SensorKit work queue and the repository's Rx chains, so an unguarded
    /// `static var` was a genuine data race (review L1) as well as a way to emit the diagnostic
    /// twice.
    private static let offsetReportLock = NSLock()
    private static var offsetReportedStorage = false

    /// Once-per-launch guard for the diagnostic below.
    static var offsetReported: Bool {
        Self.offsetReportLock.lock()
        defer { Self.offsetReportLock.unlock() }
        return Self.offsetReportedStorage
    }

    #if DEBUG
    /// Specs reset the latches between examples. `#if DEBUG` (F15): production code has no reason
    /// to un-report and must not be able to — the whole point of a latch is that the diagnostic
    /// fires once.
    static func resetReportLatchesForTesting() {
        Self.offsetReportLock.lock()
        defer { Self.offsetReportLock.unlock() }
        Self.offsetReportedStorage = false
        Self.missingOffsetReportedStorage = false
    }
    #endif

    /// `mark` value of the `sensor_data_clock_ahead` event when it means "no offset has ever been
    /// recorded", rather than a measured divergence (F8).
    static let noOffsetMark = "no_server_offset"

    private static var missingOffsetReportedStorage = false

    /// Once per launch, when a backfill plan is built while no offset has ever been recorded, say
    /// so (F8). Everything the server clock protects — the planning cap and the 365-day floor —
    /// is inert in that state, and the absence is otherwise indistinguishable from a healthy
    /// clock: `now()` simply returns `Date()` and nothing is emitted. Falsifiability breadcrumb,
    /// not an error: a device that has never had a successful response is a normal first launch.
    static func reportMissingOffsetOnce(analytics: AnalyticsService?,
                                        deviceNow: Date = Date(),
                                        defaults: UserDefaults = .standard) {
        guard Self.storedOffset(defaults: defaults) == nil else { return }
        Self.offsetReportLock.lock()
        let claimed = Self.missingOffsetReportedStorage == false
        if claimed { Self.missingOffsetReportedStorage = true }
        Self.offsetReportLock.unlock()
        guard claimed else { return }
        analytics?.track(event: .sensorDataClockAhead(mark: Self.noOffsetMark,
                                                      deviceNow: ISO8601DateFormatter().string(from: deviceNow)))
    }

    /// Test-and-set in one critical section: `true` for exactly one caller per launch. A separate
    /// get + set would let two queues both read `false` and both report.
    private static func claimOffsetReport() -> Bool {
        Self.offsetReportLock.lock()
        defer { Self.offsetReportLock.unlock() }
        guard Self.offsetReportedStorage == false else { return false }
        Self.offsetReportedStorage = true
        return true
    }

    /// RFC 7231 IMF-fixdate, the only format an HTTP `Date` header may use in practice.
    /// `en_US_POSIX` + a fixed GMT zone: never locale- or timezone-dependent.
    private static let headerFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    /// Persist the offset carried by one response's `Date` header. No-op for a missing or
    /// unparsable header (a proxy that strips it must not move the clock), and for a change
    /// below `persistenceGranularity`.
    static func record(headerDate: String?,
                       deviceNow: Date = Date(),
                       defaults: UserDefaults = .standard) {
        guard let headerDate = headerDate,
              let serverNow = Self.headerFormatter.date(from: headerDate) else { return }
        let offset = serverNow.timeIntervalSince(deviceNow)
        let stored = defaults.object(forKey: Self.storageKey) as? Double
        guard stored == nil || abs(offset - (stored ?? 0)) > Self.persistenceGranularity else { return }
        defaults.set(offset, forKey: Self.storageKey)
    }

    /// The stored offset, or `nil` when no response has ever been observed.
    static func storedOffset(defaults: UserDefaults = .standard) -> TimeInterval? {
        return defaults.object(forKey: Self.storageKey) as? Double
    }

    /// Server time as best we know it. Falls back to the device clock when no offset was ever
    /// stored — that is the pre-FUAM-3964 behaviour, not a new failure mode.
    static func now(current: Date = Date(),
                    defaults: UserDefaults = .standard,
                    analytics: AnalyticsService? = nil) -> Date {
        guard let offset = Self.storedOffset(defaults: defaults) else { return current }
        Self.reportOffsetOnce(offset: offset, deviceNow: current, analytics: analytics)
        return current.addingTimeInterval(offset)
    }

    /// A device clock more than a day away from the server's is otherwise invisible: the plan
    /// silently shrinks (clock behind) or the samples carry wrong timestamps (clock ahead).
    /// FUAM-3835 ran for six weeks on exactly that kind of silence.
    private static func reportOffsetOnce(offset: TimeInterval, deviceNow: Date, analytics: AnalyticsService?) {
        guard abs(offset) > Self.aheadReportThreshold else { return }
        guard Self.claimOffsetReport() else { return }
        let formatter = ISO8601DateFormatter()
        let serverNow = deviceNow.addingTimeInterval(offset)
        analytics?.track(event: .sensorDataClockAhead(mark: formatter.string(from: serverNow),
                                                      deviceNow: formatter.string(from: deviceNow)))
    }
}
