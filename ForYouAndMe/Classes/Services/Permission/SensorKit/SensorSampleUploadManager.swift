//
//  SensorSampleUploadManager.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import CryptoKit
import Foundation
import RxSwift
import SensorKit

/// Coordinates SensorKit ingestion:
/// 1) Fetch window [cursor, now] via per-sensor mapper
/// 2) Split into batches and enqueue
/// 3) Upload batches using network delegate
/// 4) Advance cursor on success; retry with backoff on failure
public final class SensorSampleUploadManager {

    // MARK: - Config

    /// Maximum number of records in a single batch upload.
    private let maxBatchSize: Int = 500

    /// Minimum time between auto-sync cycles (avoid noisy triggers). 15 SECONDS — the comment
    /// used to say minutes, the value never did. Kept as is: since the in-flight chain guard
    /// (review C1) a cycle that arrives while a sensor is still fetching is skipped rather than
    /// re-entering its mapper, so the throttle no longer protects anything and a short interval
    /// only costs an empty plan lookup. Changing the cadence is a separate decision.
    private let minSyncInterval: TimeInterval = 15

    /// Exponential backoff boundaries for retry.
    private let retryBaseDelay: TimeInterval = 30
    private let retryMaxDelay: TimeInterval = 15 * 60
    
    private let sensorkitEmbargo: TimeInterval = 24 * 60 * 60   // 24h absolute duration

    /// The server rejects requests above 10 MB (HTTP 413 PayloadTooLarge). Keep each queued
    /// batch's serialized JSON safely below that; the upload envelope adds only a few bytes.
    private let maxBatchBytes: Int = 5 * 1024 * 1024

    /// Give up on a window after this many consecutive failed fetch attempts and move past it,
    /// so one poison window doesn't stall the per-sensor chain forever (FUAM-3841).
    private let maxWindowFetchAttempts: Int = 3

    /// FUAM-3945 round 5 (AC6): upload budget for a queued batch the server PERMANENTLY
    /// rejects (`SensorUploadError.permanentlyRejected` — the 4xx validation class; transient
    /// failures never count). On exhaustion the batch is dropped from the persisted queue —
    /// reported via `upload_stuck` + `sensor_record_dropped`, never silently — so one poisoned
    /// batch cannot sit in the queue for the life of the install.
    private let maxBatchUploadRejections: Int = 3

    /// FUAM-3945 (D3): how many complete participant-tz days behind the cursor are re-planned,
    /// once per day. Aug 27 in production was 64/96 buckets ~24.5h after day end and complete at
    /// ~38h, so 3 days covers any observed write lag with margin; `sensor_rescan_novel` measures
    /// the real completion curve so this constant can be tuned from the field.
    static let rescanTailDays: Int = 3

    /// FUAM-3945 (D4): ledger entries are pruned once their day falls this many days behind the
    /// planning day — rescan depth + 2 days of margin, so nothing the rescan can re-fetch is ever
    /// forgotten while it still matters. Over-pruning only costs a re-upload the server
    /// union-merges; under-pruning only costs storage.
    static let ledgerRetentionDays: TimeInterval = TimeInterval(rescanTailDays) + 2

    /// FUAM-3945 (AC1): a BACKFILL walk probes windows newest-first and stops extending backwards
    /// after this many CONSECUTIVE confirmed-empty windows — the adaptive replacement for any
    /// hardcoded OS-retention assumption. If a future iOS retains 4 weeks instead of 7 days, the
    /// probe simply keeps finding data and keeps going; the join-day consent bound and the
    /// 365-day cap remain the only hard ceilings.
    static let probeEmptyWindowStop: Int = 2

    /// FUAM-3945 (round 4): how many records a backward probe may hold buffered in memory while
    /// it discovers the retention horizon. The probe FETCHES newest-first (that is what makes
    /// the horizon discoverable without walking hundreds of empty windows) but ENQUEUES
    /// oldest-first, by buffering each window's record set and flushing the buffer
    /// chronologically at probe termination. A fresh install against a dense sensor and a long
    /// OS retention could buffer a lot, so past this cap the buffer is flushed early and the
    /// rest of the probe falls back to enqueue-as-you-go (still correct — the membership filter
    /// stays in place there — just no longer strictly chronological), with a
    /// `probe_buffer_overflow` telemetry trace. Counted in records, not serialized bytes:
    /// measuring bytes would cost a serialization pass larger than the buffer itself.
    /// Internal and mutable for the overflow specs only.
    var probeBufferMaxRecords: Int = 10_000

    // MARK: - Dependencies

    private let sensors: [SRSensor]
    private let storage: SensorSampleUploadManagerStorage & SensorSampleUploaderStorage
    private let reachability: SensorSampleUploadManagerReachability
    private let analytics: AnalyticsService
    private let mappers: [SRSensor: SensorSampleMapper]
    /// FUAM-3945: which devices (iPhone / paired Watch) hold data for each sensor.
    private let deviceProvider: SensorDeviceProvider

    /// Provided later by the owner (e.g., SensorKitManager) to perform actual uploads.
    private weak var networkDelegate: SensorSampleUploaderNetworkDelegate?
    
    // State
    private var hasPurgedForNoUser = false

    // Background queue to avoid blocking UI
    private let workQueue = DispatchQueue(label: "com.foryouandme.sensor.upload", qos: .utility)
    
    /// Optional clearance gate. If `false`, the manager will not fetch/upload.
    public weak var clearanceDelegate: SensorSampleUploadManagerClearanceDelegate?

    // MARK: - State

    private let disposeBag = DisposeBag()
    private var lastSyncDate: Date?
    // Mutated ONLY on `workQueue` (review fix #10 — mapper callbacks arrive on arbitrary
    // threads and are hopped onto the work queue before touching this state).
    private var retryWorkItems: [SRSensor: DispatchWorkItem] = [:]
    // ponytail: in-memory per-sensor consecutive-failure counter, reset on any success
    // (review fix #5 — keying on window.start never fired when the bound shifted every
    // cycle). Resets on relaunch; persist it in storage if poison windows turn out to
    // survive app restarts.
    // FUAM-3945: keyed by sensor AND device kind (`DeviceChainContext.failureKey`), so a poison
    // Watch window can never stall the iPhone chain.
    private var windowFetchFailures: [String: Int] = [:]
    // FUAM-3945 round 5 (AC6): per-batch permanent-rejection counter, mutated on `workQueue`
    // only (the drain's failure callback hops there first).
    // ponytail: in-memory, so a relaunch refunds the budget — the safe direction: a genuinely
    // permanent rejection recurs on every drain of the same session, so it still exhausts;
    // persist alongside the queue only if field telemetry shows stuck batches surviving it.
    private var batchUploadRejections: [String: Int] = [:]
    // Once-per-launch guard so the "empty_plan" telemetry (review fix #6) doesn't fire on
    // every 15-minute sync cycle while a fresh enrollment waits out the 24h embargo.
    private var emptyPlanReported: Set<String> = []
    // FUAM-3945 (review C1): sensors whose device chain has not yet reached a termination path.
    // `syncAllSensors` releases `syncLock` as soon as it has KICKED OFF every chain, and the
    // reachability trigger bypasses the sync throttle entirely, so a second cycle used to
    // re-enter `runDeviceChain` and call `fetchAndMap` on a mapper with a fetch already in
    // flight. Every mapper is single-flight; three of them used to `precondition` on that, i.e.
    // crash in Release. A sensor already in flight is now simply skipped — the next cycle picks
    // it up — and, crucially, skipping is NOT a fetch failure, so it burns nothing towards
    // `windowFetchFailures` and can never trigger the give-up cursor skip.
    // ponytail: a mapper that never fires its completion now blocks its own sensor until the
    // next launch. That chain was already stalled (the cursor never advanced either way); the
    // guard turns "stalled, then crashed on the next cycle" into "stalled". Add a watchdog only
    // if a real mapper is ever seen dropping a completion.
    private var activeChains: Set<SRSensor> = []
    /// Once-per-launch guard for the `sensor_tz_fallback` diagnostic (AC2 revised).
    private var tzFallbackReported = false
    /// Guards `activeChains` only. Deliberately NOT `syncLock`: `beginChain` is reached from
    /// inside `syncAllSensors`, which already holds `syncLock` (NSLock is not recursive).
    private let chainLock = NSLock()
    private let syncLock = NSLock()
    private var hasStarted = false

    // MARK: - Init

    init(withSensors sensors: [SRSensor],
         storage: SensorSampleUploadManagerStorage & SensorSampleUploaderStorage,
         reachability: SensorSampleUploadManagerReachability,
         analytics: AnalyticsService,
         mappers: [SRSensor: SensorSampleMapper],
         deviceProvider: SensorDeviceProvider = DefaultSensorDeviceProvider()) {
            precondition(!sensors.isEmpty, "Sensors must not be empty")
            self.sensors = sensors
            self.storage = storage
            self.reachability = reachability
            self.analytics = analytics
            self.mappers = mappers
            self.deviceProvider = deviceProvider
    }

    /// A paired Watch only shows up in `fetchDevices()` once it has synced data for the sensor,
    /// so the enumeration legitimately changes over time. Call this when the app comes to the
    /// foreground (FUAM-3945); the next sync cycle then re-enumerates.
    public func refreshDeviceCache() {
        self.deviceProvider.invalidate()
    }

    // MARK: - Wiring

    /// Call this right after creating the manager, when your network layer is available.
    public func setNetworkDelegate(_ delegate: SensorSampleUploaderNetworkDelegate) {
        self.networkDelegate = delegate
        if hasStarted, (clearanceDelegate?.sensorManagerCanRun ?? true) {
            // Kick a sync now that uploads are possible
            triggerSync(reason: "net_delegate_ready")
        }
    }

    // MARK: - Lifecycle

    /// Start reactive logic (reachability listeners + initial sync).
    public func startUploadLogic() {
    
        hasStarted = true

        // If there is no clearance (no user / no consent), purge and do nothing
        guard clearanceDelegate?.sensorManagerCanRun ?? false else {
            if !hasPurgedForNoUser {
                hasPurgedForNoUser = true
                self.trackClearanceMismatchIfNeeded(reason: "no_clearance_at_start")
                // run purge async to avoid blocking startup
                workQueue.async { [weak self] in self?.purgeAllData(reason: "no_clearance_at_start") }
            }
            return
        }
        hasPurgedForNoUser = false
        
        guard networkDelegate != nil else {
            #if DEBUG
            print("SensorSampleUploadManager - Deferring start: network delegate not set yet")
            #endif
            return
        }
        
        // React when network comes back up
        reachability.reachabilityChanged
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] reachable in
                guard let self else { return }
                if reachable {
                    self.triggerSync(reason: "reachability_up")
                }
            })
            .disposed(by: disposeBag)

        // Initial sync
        triggerSync(reason: "startup")
    }

    /// You can call this from foreground flows or background tasks to force a sync cycle.
    public func triggerSync(reason: String = "manual") {
        
        // Clearance check every time: if missing, purge once and exit
        guard clearanceDelegate?.sensorManagerCanRun ?? false else {
            if !hasPurgedForNoUser {
                hasPurgedForNoUser = true
                self.trackClearanceMismatchIfNeeded(reason: "no_clearance_trigger")
                workQueue.async { [weak self] in self?.purgeAllData(reason: "no_clearance_trigger") }
            }
            return
        }
        hasPurgedForNoUser = false
        
        if let last = lastSyncDate, Date().timeIntervalSince(last) < minSyncInterval, reason != "reachability_up" {
            // Throttle frequent triggers unless connectivity just changed
            return
        }
        lastSyncDate = Date()
        
        // Run on background queue to avoid blocking the main thread
        workQueue.async { [weak self] in
            self?.syncAllSensors()
        }
    }

    // MARK: - Core

    private func syncAllSensors() {
        
        guard clearanceDelegate?.sensorManagerCanRun ?? true else { return }

        // Ensure single-cycle at a time
        syncLock.lock(); defer { syncLock.unlock() }

        let now = Date()

        // Fetch & enqueue (mappers can be async but we trigger drains below)
        for sensor in sensors {
            fetchPendingWindows(for: sensor, now: now)
        }

        // Try to drain queues
        for sensor in sensors {
            drainQueue(for: sensor)
        }
    }
    
    private func isAuthorized(_ sensor: SRSensor) -> Bool {
        return SRSensorReader(sensor: sensor).authorizationStatus == .authorized
    }
    
    private func statusString(_ sensor: SRSensor) -> String {
        switch SRSensorReader(sensor: sensor).authorizationStatus {
        case .authorized:     return "authorized"
        case .denied:         return "denied"
        case .notDetermined:  return "notDetermined"
        @unknown default:     return "unknown"
        }
    }
    
    /// The report-like sensors SensorKit indexes by WRITE time, aggregated over a day. They no
    /// longer get their own window scheme (round 7: every sensor is windowed on complete UTC
    /// days), but the per-record consent gate still needs to know which sensors they are — a
    /// report written inside the first window describes the previous, pre-consent day, so its
    /// window only vouches for undecidable records when it opens STRICTLY above the bound
    /// (see `windowVouches`).
    static let dayAggregatedSensors: Set<SRSensor> = [
        .deviceUsageReport, .phoneUsageReport, .messagesUsageReport, .keyboardMetrics
    ]
    
    /// The windows to fetch for a sensor, plus the effective lower bound and what
    /// determined it (see `BackfillLowerBound.Origin`) — used for telemetry.
    struct WindowPlan {
        let windows: [DateInterval]
        let lowerBound: Date
        let lowerBoundOrigin: BackfillLowerBound.Origin
        /// The consent bound (`BackfillLowerBound.date`) as resolved when the plan was built,
        /// carried through to the per-record gate (review fix #5). Unlike `lowerBound` it is
        /// never moved forward by the cursor, so a day-aligned window that legitimately opens
        /// before a mid-day cursor is still filtered against the join day and not the cursor.
        let consentBound: Date
        /// FUAM-3945 (D3): non-nil when the plan's start was rewound behind the cursor by the
        /// once-per-UTC-day rescan tail — the value is the rewound start. `nil` on a plain
        /// cursor resume, on a backfill (which covers the recent days anyway) and when the
        /// rescan already ran today.
        let rescanFrom: Date?
    }

    /// The consent bound as it stands right now, resolved from the live user record.
    private var currentBound: BackfillLowerBound {
        // FUAM-3964 (review I1): `max(deviceNow, serverNow)`, never the raw device clock — the
        // 365-day cap is `now - 365d`, so a clock rolled back Δ would let it reach 365 + Δ.
        return BackfillLowerBound.resolve(joinDay: self.clearanceDelegate?.enrollmentDate,
                                          now: max(Date(), ServerClock.now()))
    }

    /// Internal rather than private so the FUAM-3964 server-time cap can be exercised through
    /// this real call path: `fetchPendingWindows` bails out before planning on the simulator
    /// (no sensor is ever `.authorized` there), so this is the outermost reachable seam.
    func buildWindowPlan(for sensor: SRSensor, now: Date, device: SensorDevice) -> WindowPlan {
        // FUAM-3964: plan against `min(deviceNow, serverNow)`. A device clock in the future would
        // otherwise plan windows up to that instant and write the cursor there; correcting the
        // clock would then leave a hole the plan can never reopen (the cursor only moves forward).
        // Capping at server time means any clock excursion self-heals on the next sync. The
        // mapper's fetch still uses device wall-clock — SensorKit indexes its store with the same
        // clock that wrote the samples.
        // FUAM-3945: only the cursor position and the upper bound differ per device. The
        // holdback SUBSUMES the embargo rather than adding to it (`max`, not `+`), so the watch
        // upper bound is `min(deviceNow, serverNow) - 48h` — still snapped to complete UTC days
        // by the pure planner, which needs no device knowledge at all.
        // FUAM-3964 (review I1): the two bounds want OPPOSITE ends of the clock disagreement.
        // The upper bound takes `min` (never plan past server time); the 365-day hard cap is a
        // LOWER bound, so it takes `max` — a clock rolled BACK would otherwise move `now - 365d`
        // back with it and let the cap reach 365 + Δ real days. The later of the two clocks can
        // only ever tighten a lower bound, so `max` is the safe direction there.
        // F8: one breadcrumb per launch when the cap has never had anything to cap with.
        ServerClock.reportMissingOffsetOnce(analytics: self.analytics)
        let serverNow = ServerClock.now()
        let cappedNow = min(now, serverNow)
        let embargo = max(sensorkitEmbargo, device.syncHoldback)
        // AC2 (revised): the partition timezone is the BACKEND-authoritative `user.time_zone` —
        // the same authority the adherence chart buckets rows with — never the handset's.
        let timeZone = self.partitionTimeZone()
        let calendar = Self.partitionCalendar(timeZone)
        // FUAM-3945 (D3): once per day, the plan's start is rewound to re-read the last
        // `rescanTailDays` complete participant-tz days behind the cursor — the fix for late
        // writes (D-D: Aug 27 was 64/96 buckets when fetched ~24.5h after day end and complete
        // at ~38h). The re-reads are ordinary grid windows walked by the same code; records
        // already uploaded are dropped by the D4 ledger, so a rescan's steady-state upload
        // volume is zero. The gate is persisted per sensor+device so a 15-second sync cadence
        // cannot multiply it.
        let planDay = Self.utcDayStart(cappedNow)
        let rescanDue = storage.lastRescanDay(for: sensor, deviceKey: device.key).map { planDay > $0 } ?? true
        var rescanFrom: Date?
        if rescanDue {
            let safeTo = cappedNow.addingTimeInterval(-embargo)
            rescanFrom = calendar.date(byAdding: .day,
                                       value: -Self.rescanTailDays,
                                       to: calendar.startOfDay(for: safeTo))
            // Burned at plan time, deliberately: the rescan is best-effort redundancy (every day
            // gets `rescanTailDays` passes), so a chain that fails mid-walk just waits for
            // tomorrow's tail rather than re-arming today's on every sync cycle.
            storage.setLastRescanDay(planDay, for: sensor, deviceKey: device.key)
        }
        return Self.buildWindowPlan(now: cappedNow,
                                    boundNow: max(now, serverNow),
                                    joinDay: clearanceDelegate?.enrollmentDate,
                                    cursor: storage.lastCursor(for: sensor, deviceKey: device.key),
                                    embargo: embargo,
                                    timeZone: timeZone,
                                    rescanFrom: rescanFrom)
    }

    /// The backend-authoritative participant timezone, or the deterministic UTC fallback —
    /// reported once per launch, because a fallback means the partition MAY not match the
    /// adherence chart's bucketing until the user record loads. Never `TimeZone.current` (AC2).
    private func partitionTimeZone() -> TimeZone {
        if let timeZone = self.clearanceDelegate?.participantTimeZone {
            return timeZone
        }
        if !self.tzFallbackReported {
            self.tzFallbackReported = true
            self.analytics.track(event: .sensorTimezoneFallback(reason: "missing_user_time_zone"))
        }
        return Self.fallbackPartitionTimeZone
    }

    /// One nominal day. Used ONLY for tz-agnostic bookkeeping (ledger pruning tags, telemetry
    /// age buckets, the future-cursor tolerance) — NEVER as a partition stride: participant-day
    /// boundaries come from `partitionCalendar` and can be 23 or 25 hours long on a DST day.
    static let utcDay: TimeInterval = 24 * 60 * 60

    /// Start of the UTC calendar day containing `date`. Tz-agnostic bookkeeping only (see above).
    static func utcDayStart(_ date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: (seconds / Self.utcDay).rounded(.down) * Self.utcDay)
    }

    /// The partition fallback when no backend-authoritative `user.time_zone` is available
    /// (AC2 revised): UTC — deterministic and travel-independent. Deliberately NEVER
    /// `TimeZone.current`, which would silently reintroduce handset-dependence.
    static let fallbackPartitionTimeZone = TimeZone(identifier: "UTC")!

    /// The calendar every window/batch boundary is computed in (AC2 revised): gregorian, pinned
    /// to the participant's backend-authoritative timezone. A pure function of the timezone
    /// identifier — `Calendar.current` / `TimeZone.current` must never appear in the planner.
    static func partitionCalendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The first participant-day boundary STRICTLY after `date` — 23/24/25 real hours away,
    /// depending on DST. `date` on a boundary yields the next one.
    static func nextDayStart(after date: Date, in calendar: Calendar) -> Date {
        // The gregorian calendar cannot fail this; the fallback keeps the walk total anyway.
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(Self.utcDay)
    }

    /// Build embargo-safe fetch windows from the backfill lower bound up to now.
    ///
    /// **Windows are complete UTC calendar days** — `[00:00 UTC, next 00:00 UTC)` — for EVERY
    /// sensor, continuous or day-aggregated (FUAM-3945 round 7). Only a window whose end is at or
    /// before `safeTo` is planned, so a day is fetched once, complete, and never re-fetched
    /// partially; combined with the 24h SensorKit embargo the accepted latency is up to ~48h.
    ///
    /// Why UTC rather than the previous `Calendar.current` day alignment (report sensors) and
    /// cursor-relative 24h chunks (continuous sensors): a fetch window selects on the OS's WRITE
    /// time, so the alignment does not change WHICH data is collected, only how it is cut. Making
    /// the cut timezone-independent makes the boundaries reproducible — same device, same days,
    /// whatever the participant's travel or a reinstall did to the local calendar — which is what
    /// makes the backend's semantic anchors reproducible across re-uploads.
    ///
    /// **One-time migration window**: a cursor left by an older build sits at an arbitrary
    /// instant. When it is not UTC-midnight-aligned the first planned window is the partial
    /// `[cursor, next UTC midnight)`, after which every window is a whole UTC day. That partial
    /// window is unique per device and forward-only, so it is planned exactly once and never
    /// repeats.
    ///
    /// The lower bound is the shared FUAM-3945 policy (`BackfillLowerBound`): the study join day,
    /// floored at 365 days, forward-only when no join day can be established. Over-requesting is
    /// free — `SRSensorReader.fetch` simply returns nothing for a window the OS has already
    /// dropped — so this no longer clamps to an assumed OS retention.
    ///
    /// `now` must already be capped at server time by the caller — `min(deviceNow, serverNow)`
    /// (FUAM-3964). `boundNow` is the same instant resolved the other way, `max(deviceNow,
    /// serverNow)`, and is used ONLY for the 365-day hard cap: capping a lower bound with a
    /// clock that may have been rolled backwards would let the reach grow past 365 real days
    /// (review I1). Pure (internal for unit tests).
    ///
    /// `rescanFrom` (FUAM-3945, D3): when non-nil, the plan start becomes
    /// `max(consentBound, min(cursorFrom, rescanFrom))`, re-planning the recent complete UTC
    /// days BEHIND the cursor as ordinary grid windows. Never lowers the start below the
    /// consent bound, never moves a start that is already at or below it.
    static func buildWindowPlan(now: Date,
                                boundNow: Date,
                                joinDay: Date?,
                                cursor: Date?,
                                embargo: TimeInterval,
                                timeZone: TimeZone = SensorSampleUploadManager.fallbackPartitionTimeZone,
                                rescanFrom: Date? = nil) -> WindowPlan {
        // Upper bound: honour the 24h SensorKit embargo. No day alignment here — completeness is
        // enforced per window below (`end <= safeTo`), which is the same guarantee without
        // throwing away the fraction of a day between the last boundary and the cutoff.
        let safeTo = now.addingTimeInterval(-embargo)

        // Lower bound: join day, capped at 365 days, forward-only (== now, hence an empty
        // plan until the join day resolves) when the join day is unknown.
        let bound = BackfillLowerBound.resolve(joinDay: joinDay, now: boundNow)
        let lowerBound = bound.date
        var origin = bound.origin

        // Resume from the cursor when it is ahead of the lower bound. A cursor left behind
        // by purge + re-consent (FUAM-3844 keeps it in place) reopens from the bound —
        // never from `now` — so the gap is re-fetched.
        var from = lowerBound
        if let cursor = cursor, cursor > lowerBound {
            if BackfillLowerBound.isFutureBurned(cursor: cursor, upperBound: safeTo) {
                // FUAM-3964 (F1): a cursor more than a day above the capped upper bound was
                // written by a clock that was wrong, offline, and therefore uncapped. Leaving it
                // in place means the interval between the excursion and the cursor is never
                // fetched — the plan comes out empty until real time passes the cursor, and then
                // resumes AT it. Plan from the bound instead: the caller resets the stored cursor
                // and reports `future_cursor`. See `BackfillLowerBound.isFutureBurned` for why
                // this rewind is safe (UTC-day windows re-fetch idempotently).
                origin = .futureCursor
            } else {
                from = cursor
                origin = .cursor
            }
        }

        // FUAM-3945 (D3): the rescan tail — re-open the recent days behind the cursor. Applied
        // AFTER the cursor resolution so `origin` stays `.cursor` (a rescan is a routine pass,
        // not a backfill: it must not re-emit reach telemetry on every tail).
        var appliedRescanFrom: Date?
        if let rescanFrom = rescanFrom {
            let rewound = max(lowerBound, min(from, rescanFrom))
            if rewound < from {
                appliedRescanFrom = rewound
                from = rewound
            }
        }

        guard from < safeTo else {
            return WindowPlan(windows: [],
                              lowerBound: from,
                              lowerBoundOrigin: origin,
                              consentBound: lowerBound,
                              rescanFrom: nil)
        }

        // AC2 (revised 2026-08-29): windows are complete PARTICIPANT-timezone calendar days —
        // the same day the backend's adherence chart buckets rows with
        // (`date_histogram(time_zone: user.time_zone)`), so a batch's anchor
        // (`min(records[].recorded_at)`) is inside the day it describes by construction. Proper
        // calendar arithmetic, never a fixed 86400 stride: a DST spring-forward day is 23 hours
        // and a fall-back day is 25. The timezone is the BACKEND-authoritative `user.time_zone`,
        // never the handset's, so the partition is a pure function of (absolute time, timezone
        // identifier): travel and reinstall reproduce identical boundaries and identical anchors.
        let calendar = Self.partitionCalendar(timeZone)
        var windows: [DateInterval] = []
        var start = from
        // Migration window: [cursor, next participant-day boundary). Skipped when `from` is
        // already aligned (steady state) and when the partial day is not complete yet — in which
        // case `start` moves past `safeTo` and the loop below plans nothing, exactly as intended.
        if start != calendar.startOfDay(for: start) {
            let boundary = Self.nextDayStart(after: start, in: calendar)
            if boundary <= safeTo {
                windows.append(DateInterval(start: start, end: boundary))
            }
            start = boundary
        }
        while true {
            let end = Self.nextDayStart(after: start, in: calendar)
            guard end > start, end <= safeTo else { break }
            windows.append(DateInterval(start: start, end: end))
            start = end
        }

        return WindowPlan(windows: windows,
                          lowerBound: from,
                          lowerBoundOrigin: origin,
                          consentBound: lowerBound,
                          rescanFrom: appliedRescanFrom)
    }

    /// FUAM-3945 (D1, F4): how far a report-class FETCH reaches back beyond its window start.
    /// A device-local-calendar-day report (SensorKit returns a usage report only when its whole
    /// period fits inside the fetch range — the containment behaviour that killed
    /// `phone_usage_report` on every non-UTC device) can start up to 14h before or after the
    /// participant-day boundary the grid uses. 26h, not 24h (review round 1, F4): a 25-hour
    /// DST fall-back report day combined with a participant-tz 25-hour window on the same date
    /// (device one zone west of the profile zone — a traveller inside the same DST bloc) leaves
    /// a 1-hour placement hole under a 24h widen, so that day fits NO window on any of its four
    /// passes. The extra over-fetch is dropped by the window-membership filter and the ledger.
    static let reportFetchLookback: TimeInterval = 26 * 60 * 60

    /// FUAM-3945 (D1): 1-second backward epsilon for the continuous sensors. `from` is
    /// documented EXCLUSIVE, `to` inclusivity is undocumented; under exclusive-both a record
    /// stamped exactly on a UTC midnight is returned by neither adjacent window. The epsilon
    /// makes it always returned by the later window; any double-return under an inclusive `to`
    /// is absorbed by the upload ledger (D4).
    static let continuousFetchEpsilon: TimeInterval = 1

    /// The span handed to the MAPPER for one planned window (FUAM-3945, D1). Decoupled from the
    /// cursor grid on purpose: the cursor, `enqueueBatch(windowStart:)` and `windowVouches` all
    /// keep the NARROW `window` — widening any of them would either re-open a consent hole
    /// (a widened `windowStart` would let a pre-join report be vouched for) or break the grid.
    /// Over-fetch is upload-free because the ledger drops re-fetched records — unconditionally,
    /// on every path, since round 4: the forward walk processes the older window first by
    /// construction, and the backward probe FETCHES newest-first but ENQUEUES oldest-first (the
    /// buffered flush in `flushProbeBuffer`), so by the time a widened fetch's batch is
    /// committed, the previous day's records are already fingerprinted. The one exception is the
    /// probe's rare buffer-overflow fallback, where `belongsToOlderProbeWindow` (review round 1,
    /// F1) still carries the load; everywhere else it is a defensive guard.
    static func fetchSpan(for sensor: SRSensor, window: DateInterval) -> DateInterval {
        let lookback = Self.dayAggregatedSensors.contains(sensor)
            ? Self.reportFetchLookback
            : Self.continuousFetchEpsilon
        return DateInterval(start: window.start.addingTimeInterval(-lookback), end: window.end)
    }

    /// F1 (review round 1): window-membership rule for the BACKWARD probe. The probe FETCHES
    /// newest-first, so window W's widened fetch returns the previous day's records BEFORE
    /// their own window has run; on a fresh/reinstalled device the ledger is empty, so without
    /// a membership rule both days landed in ONE batch anchored at the older day's minimum — a
    /// permanently rowless newest day (a false "no data" adherence dot) on every fresh install,
    /// cross-row duplication on reinstall, and batch composition dependent on walk direction
    /// (AC2's rule, violated verbatim).
    ///
    /// ROUND 4: no longer load-bearing on the main probe path. The probe now buffers its
    /// windows and ENQUEUES them oldest-first (`flushProbeBuffer`), so the ledger drops the
    /// over-fetched previous-day records exactly as it does on the forward walk — ordering does
    /// for free what this predicate held by cleverness. It survives in two roles:
    /// - DEFENSIVE guard at the terminal flush, with a DEBUG assertion that it defers nothing
    ///   (anything left for it there is an ordering regression, or an OS fetch that defied the
    ///   containment model — either way it must be loud, not silent);
    /// - the load-bearing filter on the buffer-OVERFLOW fallback, where newer windows are
    ///   enqueued before their older neighbours have been fetched, i.e. the original round-2/3
    ///   regime this predicate was verified for.
    ///
    /// A record is deferred to the OLDER window iff its measurement time precedes this window
    /// AND the older window's own widened span would actually return it under BOTH candidate
    /// SensorKit selection semantics — containment of the measurement period (`from` exclusive,
    /// `to` inclusive) AND write-time membership (`recorded_at` inside the span). Deferring is
    /// the only lossy direction: a traveller's device-local report can straddle the boundary
    /// such that ONLY the newer window's span contains it, and a late-written bucket carries a
    /// `recorded_at` beyond the older span — in either case the record is KEPT here, which is
    /// exactly where the forward walk binds it too, so order-independence is preserved.
    /// Undecidable records (no readable measurement time) stay bound to the window that fetched
    /// them, guarded by the conservative widened-anchor vouch.
    static func belongsToOlderProbeWindow(_ record: [String: Any],
                                          sensor: SRSensor,
                                          window: DateInterval,
                                          olderWindow: DateInterval) -> Bool {
        guard let measured = Self.measurementTime(of: record, sensor: sensor),
              measured < window.start else { return false }
        let olderSpan = Self.fetchSpan(for: sensor, window: olderWindow)
        if Self.dayAggregatedSensors.contains(sensor) {
            // Report sensors: period CONTAINMENT is the evidenced selection semantics (the
            // window-loss report refuted write-time selection outright), so containment alone
            // decides — a write-time condition here would re-open a small order-dependence for
            // late-written reports. Only the three usage reports carry a trustworthy period
            // length (round 3, R2-1): `SRKeyboardMetrics.duration` is CUMULATIVE typing time,
            // not a period — the same adjudication `measurementTime` already made — so a
            // keyboard record with a readable start but no derivable period end is KEPT, the
            // never-lossy direction.
            guard Self.usageReportSensors.contains(sensor),
                  let duration = (record["duration_s"] as? NSNumber)?.doubleValue else { return false }
            let periodEnd = measured.addingTimeInterval(Swift.max(0, duration))
            return measured > olderSpan.start && periodEnd <= olderSpan.end
        }
        // Continuous sensors: the record is a point at `measured`. Only defer when the older
        // fetch would ALSO see it under write-time selection (visits is write-time-indexed with
        // DAYS of lag). An unreadable `recorded_at` keeps the record here (never lossy).
        guard measured > olderSpan.start, measured <= olderSpan.end,
              let recordedAtString = record["recorded_at"] as? String,
              let recordedAt = Self.parseISO8601(recordedAtString) else { return false }
        return recordedAt > olderSpan.start && recordedAt <= olderSpan.end
    }

    /// Everything one device's window walk needs that does not change inside that walk, plus
    /// what it needs to hand over to the NEXT device when it ends (FUAM-3945). A struct rather
    /// than seven more parameters on `processWindow` / `handleWindowResult`.
    struct DeviceChainContext {
        let sensor: SRSensor
        let device: SensorDevice
        let devices: [SensorDevice]
        let deviceIndex: Int
        let now: Date
        let mapper: SensorSampleMapper
        let plannedBound: Date
        /// The stored cursor at plan time: a window ending at or before it is a RESCAN pass
        /// (D3) — used only to label telemetry, never for control flow.
        let rescanBoundary: Date?
        /// FUAM-3945 (AC1): `true` when this walk is a backfill probe — windows are FETCHED
        /// NEWEST-first, ENQUEUED oldest-first via the buffered flush (round 4), the cursor is
        /// written once at probe termination (never per window), and the probe stops after
        /// `probeEmptyWindowStop` consecutive confirmed-empty windows.
        let backwardProbe: Bool
        /// The end of the newest planned window — the single cursor target of a completed probe.
        let planHeadEnd: Date?
        /// Consecutive confirmed-empty windows seen so far by a backward probe.
        var probeEmptyStreak: Int
        /// FUAM-3945 (round 4): the probe's per-window record sets, accumulated newest-first
        /// during discovery and flushed OLDEST-first at termination (`flushProbeBuffer`), so no
        /// code path enqueues out of chronological order.
        var probeBuffer: [ProbeBufferedWindow] = []
        /// Records currently buffered — checked against `probeBufferMaxRecords`.
        var probeBufferRecordCount: Int = 0
        /// `true` once the cap tripped: the buffer was flushed early and the rest of the probe
        /// enqueues as-you-go (the pre-round-4 regime, still correct via the membership filter).
        var probeBufferOverflowed: Bool = false
        /// Starts of windows forfeited via `gave_up` during this probe. Their stragglers in a
        /// newer window's buffer must still be DROPPED at flush (the sanctioned loss class —
        /// uploading them would anchor the newer row a day low) but must not trip the
        /// ordering-regression assertion: a fetch failure is not an ordering bug.
        var probeForfeitedWindowStarts: Set<Date> = []

        init(sensor: SRSensor,
             device: SensorDevice,
             devices: [SensorDevice],
             deviceIndex: Int,
             now: Date,
             mapper: SensorSampleMapper,
             plannedBound: Date,
             rescanBoundary: Date? = nil,
             backwardProbe: Bool = false,
             planHeadEnd: Date? = nil,
             probeEmptyStreak: Int = 0) {
            self.sensor = sensor
            self.device = device
            self.devices = devices
            self.deviceIndex = deviceIndex
            self.now = now
            self.mapper = mapper
            self.plannedBound = plannedBound
            self.rescanBoundary = rescanBoundary
            self.backwardProbe = backwardProbe
            self.planHeadEnd = planHeadEnd
            self.probeEmptyStreak = probeEmptyStreak
        }

        /// `"<sensor>.<deviceKey>"` — failure and empty-plan counters are per sensor AND device.
        var failureKey: String { return "\(self.sensor.rawValue).\(self.device.key)" }
    }

    /// One backward-probe window's consent-gated, ledger-prefiltered record set, held until the
    /// chronological flush (FUAM-3945 round 4). The prefilter at buffer time is read-only and
    /// only keeps a re-probe over already-uploaded days from ballooning the buffer; the
    /// authoritative ledger filter re-runs at flush, when earlier (older) windows of the same
    /// flush have committed their fingerprints.
    struct ProbeBufferedWindow {
        let window: DateInterval
        /// The next-older grid window at fetch time (`nil` for the plan's oldest window) — the
        /// argument the defensive membership guard needs at flush.
        let olderWindow: DateInterval?
        /// Consent-gated, ledger-prefiltered, still untagged (tagging happens at enqueue, as on
        /// every other path, so fingerprints stay device-tag-free per D4).
        let records: [[String: Any]]
        let windowDay: Date
        let isRescanPass: Bool
        let windowAgeDays: Int
    }

    private func fetchPendingWindows(for sensor: SRSensor, now: Date) {
        guard isAuthorized(sensor) else {
            #if DEBUG
            print("SensorSampleUploadManager - Skip \(sensor.rawValue): status=\(statusString(sensor))")
            #endif
            return
        }

        // Mapper
        guard let mapper = mappers[sensor] else {
            #if DEBUG
            print("SensorSampleUploadManager - Missing mapper for \(sensor.rawValue)")
            #endif
            return
        }

        runDeviceChain(at: 0, of: deviceProvider.devices(for: sensor), for: sensor, now: now, using: mapper)
    }

    /// Claim `sensor`'s chain for this cycle. `false` means one is already running and this
    /// cycle must leave the sensor alone (FUAM-3945 review C1).
    private func beginChain(for sensor: SRSensor) -> Bool {
        self.chainLock.lock()
        defer { self.chainLock.unlock() }
        return self.activeChains.insert(sensor).inserted
    }

    /// Release `sensor`'s chain. Called on EVERY chain-termination path: the `index >= count`
    /// return below (which every completed, given-up and retried walk funnels into) and the
    /// forward-only bail in `handleWindowResult`.
    private func endChain(for sensor: SRSensor) {
        self.chainLock.lock()
        defer { self.chainLock.unlock() }
        self.activeChains.remove(sensor)
    }

    /// The consecutive fetch failures recorded for one sensor+device. Internal purely so the C1
    /// spec can assert that a SKIPPED cycle burned none of the give-up budget. Must not be
    /// called from `workQueue` (it synchronises onto it).
    func windowFetchFailureCount(for sensor: SRSensor, deviceKey: String) -> Int {
        return self.workQueue.sync { self.windowFetchFailures["\(sensor.rawValue).\(deviceKey)"] ?? 0 }
    }

    /// Walk device[index]'s window plan to its end, then start device[index + 1]'s. STRICTLY
    /// sequential: every mapper is single-flight — three of them used to `precondition` on a
    /// concurrent fetch, i.e. crash — so two devices must never have a fetch in flight on the
    /// same sensor, and neither must two sync cycles (review C1: `index == 0` claims the sensor
    /// or gives up on this cycle entirely).
    ///
    /// Internal rather than private so specs can drive the real chain: no SensorKit sensor is
    /// ever `.authorized` on the simulator, so `fetchPendingWindows` returns before planning.
    func runDeviceChain(at index: Int,
                        of devices: [SensorDevice],
                        for sensor: SRSensor,
                        now: Date,
                        using mapper: SensorSampleMapper) {
        // Entry point of a chain: claim the sensor, or skip it — a second concurrent cycle must
        // never reach `fetchAndMap` on a mapper that is still fetching. `index > 0` is this same
        // chain walking on to its next device, which already holds the claim.
        if index == 0, !self.beginChain(for: sensor) {
            #if DEBUG
            print("SensorSampleUploadManager - Skip \(sensor.rawValue): a device chain is still in flight")
            #endif
            return
        }
        guard index < devices.count else {
            self.endChain(for: sensor) // every device done
            return
        }
        let device = devices[index]
        let plan = buildWindowPlan(for: sensor, now: now, device: device)
        if plan.lowerBoundOrigin == .futureCursor {
            // FUAM-3964 (F1). The stored cursor is provably corrupt (see the planner). Report it
            // with the corrupt value as the reach — that is the size of the gap being recovered —
            // and rewind the stored cursor to the consent bound so the walk below actually
            // re-fetches it. The reset is its own once-per-launch guard: the next cycle reads the
            // rewound cursor and never re-detects.
            let burned = self.storage.lastCursor(for: sensor, deviceKey: device.key) ?? plan.lowerBound
            self.analytics.track(event: .sensorDataBackfillReach(sensor: device.telemetryName(for: sensor),
                                                                 reachedBack: ISO8601DateFormatter().string(from: burned),
                                                                 boundedBy: BackfillLowerBound.Origin.futureCursor.rawValue))
            self.storage.setLastCursor(plan.lowerBound, for: sensor, deviceKey: device.key)
            #if DEBUG
            print("SensorSampleUploadManager - Cursor for \(sensor.rawValue)/\(device.key) was burnt into the future "
                  + "(\(burned)); reset to \(plan.lowerBound)")
            #endif
        }
        // FUAM-3945 (AC1): a BACKFILL plan (anything but a routine cursor resume) is walked
        // NEWEST-first, probing backwards into the OS store and stopping after
        // `probeEmptyWindowStop` consecutive confirmed-empty windows — reach is bounded by what
        // the OS actually holds, never by a hardcoded retention assumption. A cursor resume
        // (including its rescan tail) keeps the plain oldest-first walk.
        let isBackfillProbe = plan.lowerBoundOrigin != .cursor && !plan.windows.isEmpty
        let context = DeviceChainContext(sensor: sensor,
                                         device: device,
                                         devices: devices,
                                         deviceIndex: index,
                                         now: now,
                                         mapper: mapper,
                                         plannedBound: plan.consentBound,
                                         rescanBoundary: storage.lastCursor(for: sensor, deviceKey: device.key),
                                         backwardProbe: isBackfillProbe,
                                         planHeadEnd: plan.windows.last?.end)
        guard let firstWindow = plan.windows.first else {
            // Review fix #6: an empty plan on a would-be backfill (e.g. enrolled today, or a
            // forward-only bound because days_in_study <= 0 upstream) must still leave a
            // telemetry trace — otherwise a sensor that never opens a window is
            // indistinguishable from one never asked. A forward-only bound is reported as
            // such, since it is the actionable case (the join day never resolved).
            // `.futureCursor` is excluded: the reset above already reported it, with the corrupt
            // cursor as the reach rather than the (less informative) bound.
            if plan.lowerBoundOrigin != .cursor, plan.lowerBoundOrigin != .futureCursor,
               !emptyPlanReported.contains(context.failureKey) {
                emptyPlanReported.insert(context.failureKey)
                let boundedBy: BackfillLowerBound.Origin = plan.lowerBoundOrigin == .forwardOnly ? .forwardOnly : .emptyPlan
                analytics.track(event: .sensorDataBackfillReach(sensor: device.telemetryName(for: sensor),
                                                                reachedBack: ISO8601DateFormatter().string(from: plan.lowerBound),
                                                                boundedBy: boundedBy.rawValue))
            }
            #if DEBUG
            print("SensorSampleUploadManager - No windows for \(sensor.rawValue)/\(device.key) "
                  + "(already up to date or embargo)")
            #endif
            // Nothing to do for THIS device; the next one may still have windows.
            runDeviceChain(at: index + 1, of: devices, for: sensor, now: now, using: mapper)
            return
        }

        // Observability: how far back the client actually reached for this sensor. Emitted
        // only when the plan opens a backfill (not a routine cursor resume), so the study team
        // can tell "the OS deleted it" from "the client never asked". With FUAM-3945's floor
        // removed, the oldest sample that ever arrives IS Apple's real on-device retention.
        if plan.lowerBoundOrigin != .cursor, plan.lowerBoundOrigin != .futureCursor {
            analytics.track(event: .sensorDataBackfillReach(sensor: device.telemetryName(for: sensor),
                                                            reachedBack: ISO8601DateFormatter().string(from: firstWindow.start),
                                                            boundedBy: plan.lowerBoundOrigin.rawValue))
        }
        #if DEBUG
        print("SensorSampleUploadManager - \(sensor.rawValue)/\(device.key): \(plan.windows.count) window(s) "
              + "from \(firstWindow.start) (bounded by \(plan.lowerBoundOrigin.rawValue))"
              + (isBackfillProbe ? " [backward probe]" : ""))
        #endif

        // FUAM-3945 (D3/D12, C1 item 9): a rescan tail is the one moment recent windows are
        // re-read, so it is also when `SRDeletionRecord`s are worth looking for — one extra
        // fetch per sensor+device per day, telemetry only, no control flow (S10: "the gap is
        // permanent and the OS said why" vs "the gap may still fill on a later rescan").
        if let rescanFrom = plan.rescanFrom, let headEnd = plan.windows.last?.end {
            self.launchDeletionRecordProbe(for: sensor, device: device, from: rescanFrom, to: headEnd)
        }

        processWindow(at: 0, of: isBackfillProbe ? plan.windows.reversed() : plan.windows, context: context)
    }

    /// Kept alive for the duration of their fetch (`SRSensorReader` holds its delegate weakly).
    private var deletionProbes: [SensorDeletionRecordProbe] = []
    private let deletionProbeLock = NSLock()

    /// Fire-and-forget `SRDeletionRecord` reader over the rescan span (C1 item 9). Guarded by
    /// the same authorization check as the pipeline, so it never runs where fetches cannot
    /// (including the simulator, where no sensor is ever `.authorized`).
    private func launchDeletionRecordProbe(for sensor: SRSensor, device: SensorDevice, from: Date, to: Date) {
        guard self.isAuthorized(sensor) else { return }
        let probe = SensorDeletionRecordProbe(sensor: sensor)
        self.deletionProbeLock.lock()
        self.deletionProbes.append(probe)
        self.deletionProbeLock.unlock()
        probe.start(from: from, to: to, device: device) { [weak self] deletions in
            guard let self else { return }
            for deletion in deletions {
                self.analytics.track(event: .sensorDeletionRecord(
                    sensor: sensor.shortSubsource,
                    reason: deletion.reason,
                    spanSeconds: Int(deletion.end.timeIntervalSince(deletion.start))))
            }
            self.deletionProbeLock.lock()
            self.deletionProbes.removeAll { $0 === probe }
            self.deletionProbeLock.unlock()
        }
    }

    /// Sequentially process each window to respect mapper's "no concurrent fetch" precondition.
    private func processWindow(at index: Int, of windows: [DateInterval], context: DeviceChainContext) {
        guard index < windows.count else {
            if context.backwardProbe {
                // The probe reached the consent bound: flush the buffer oldest-first and, when
                // every buffered window was durably handled, park the cursor at the plan head,
                // once (AC1/AC4 — never per window during a backward walk, so a crash mid-probe
                // re-probes instead of leaving a hole).
                self.finishProbe(context: context)
                return
            }
            // This device is done: hand the mapper over to the next one (FUAM-3945).
            self.nextDeviceChain(after: context)
            return
        }

        let window = windows[index]
        // FUAM-3945 (D1): the mapper fetches the WIDENED span; everything downstream — the
        // cursor write, the enqueue windowStart, the consent gate's `windowVouches` — keeps
        // receiving the narrow `window`.
        let fetchSpan = Self.fetchSpan(for: context.sensor, window: window)
        context.mapper.fetchAndMap(from: fetchSpan.start, to: fetchSpan.end, device: context.device) { [weak self] result in
            // Mapper callbacks arrive on arbitrary threads: hop onto the serial work queue
            // before touching windowFetchFailures / retryWorkItems / storage (review fix #10).
            guard let self else { return }
            self.workQueue.async { [weak self] in
                guard let self else { return }
                self.handleWindowResult(result, window: window, at: index, of: windows, context: context)
            }
        }
    }

    /// Start the chain of the device after `context`'s. The ONLY way a device chain ends, so a
    /// failing device can never take the remaining devices down with it (FUAM-3945).
    private func nextDeviceChain(after context: DeviceChainContext) {
        self.runDeviceChain(at: context.deviceIndex + 1,
                            of: context.devices,
                            for: context.sensor,
                            now: context.now,
                            using: context.mapper)
    }

    /// Runs on `workQueue` only. Internal rather than private so the consent decisions taken
    /// here (the forward-only cursor guard and the `max(planned, re-resolved)` bound) can be
    /// exercised through this real call path instead of by calling the pure gate directly
    /// (review round 3, I3).
    func handleWindowResult(_ result: Result<[[String: Any]], Error>,
                            window: DateInterval,
                            at index: Int,
                            of windows: [DateInterval],
                            context: DeviceChainContext) {
        let sensor = context.sensor
        // Review fix #4: the user can disappear between plan build and this callback (logout,
        // session expiry, failed token refresh). The re-resolved bound is then forward-only and
        // every record would be dropped — but advancing the cursor over the rest of the plan
        // would permanently forfeit those windows and bypass FUAM-3844's "purge never
        // fast-forwards the cursor" guarantee. Bail out of the chain, cursor untouched.
        let resolvedBound = self.currentBound
        guard !resolvedBound.isForwardOnly else {
            // Consent gone is consent gone for EVERY device: this aborts the remaining device
            // chains too, deliberately (FUAM-3945).
            #if DEBUG
            print("SensorSampleUploadManager - Aborting chain for \(sensor.rawValue): no join day (cursor left in place)")
            #endif
            // Terminal path: release the sensor so it is collectable again once consent returns.
            self.endChain(for: sensor)
            return
        }
        // Review fix #5: the join day is NOT immutable (a mid-flight user refresh can move it),
        // so take the stricter of the planned and the current bound rather than trusting either.
        let boundDate = max(context.plannedBound, resolvedBound.date)

        switch result {
        case .failure(let error):
            #if DEBUG
            print("SensorSampleUploadManager - Fetch failed \(sensor.rawValue) [\(window.start) -> \(window.end)]: \(error)")
            #endif
            // AC4: a failed fetch is UNKNOWN, not empty — the cursor never moves here.
            self.handleWindowFailure(window: window, at: index, of: windows, context: context)

        case .success(let records):
            self.windowFetchFailures[Self.attemptKey(context: context, window: window)] = nil

            let deviceKey = context.device.key
            let windowDay = Self.utcDayStart(window.start)
            let isRescanPass = context.rescanBoundary.map { window.end <= $0 } ?? false
            let windowAgeDays = max(0, Int(Self.utcDayStart(context.now).timeIntervalSince(windowDay) / Self.utcDay))

            // AC1: the deepest window that ever returned data IS the measured OS retention.
            if !records.isEmpty {
                let deepest = self.storage.deepestProductiveWindowStart(for: sensor, deviceKey: deviceKey)
                if deepest == nil || window.start < deepest! {
                    self.storage.setDeepestProductiveWindowStart(window.start, for: sensor, deviceKey: deviceKey)
                    self.analytics.track(event: .sensorDeepestWindow(sensor: context.device.telemetryName(for: sensor),
                                                                     windowDay: ISO8601DateFormatter().string(from: windowDay)))
                }
            } else {
                // CONFIRMED-EMPTY: the OS answered successfully with zero records. This is the
                // one condition that may advance the cursor past a window (AC4), and it was the
                // loss path with no telemetry at all (window-loss report O6).
                self.analytics.track(event: .sensorWindowEmpty(sensor: sensor.shortSubsource,
                                                               device: deviceKey,
                                                               windowDay: ISO8601DateFormatter().string(from: windowDay),
                                                               pass: isRescanPass ? "rescan_\(windowAgeDays)" : "first"))
            }

            // Hard consent gate: drop anything measured before the backfill lower bound,
            // regardless of what SensorKit returned for the requested window. Deliberate loss,
            // never silent (AC6). The vouch anchor is the NARROW window start — with one
            // exception: a BACKWARD probe walks newest-first, so a widened report fetch can hand
            // an undecidable record to a window one day NEWER than its own before that window is
            // reached (the forward walk fetches a record's own window first and the ledger binds
            // it there). Vouching such a record on the newer window's start would let a pre-join
            // report through at the join boundary, so the probe vouches on the WIDENED span's
            // start instead — conservative, never generous.
            let vouchAnchor: Date = context.backwardProbe && Self.dayAggregatedSensors.contains(sensor)
                ? window.start.addingTimeInterval(-Self.reportFetchLookback)
                : window.start
            let gated = Self.dropPreBoundRecords(records,
                                                 lowerBound: boundDate,
                                                 windowStart: vouchAnchor,
                                                 sensor: sensor)
            if gated.count != records.count {
                self.analytics.track(event: .sensorRecordDropped(sensor: context.device.telemetryName(for: sensor),
                                                                 count: records.count - gated.count,
                                                                 reason: "consent_gate"))
            }

            // Round 4: the probe's main path BUFFERS instead of enqueueing, so the flush can
            // enqueue oldest-first and the ledger — not walk order — owns the dedup on every
            // path. Batch COMPOSITION is untouched (AC2): the same pure filters run, only the
            // sequence batches reach the queue in changes.
            if context.backwardProbe, !context.probeBufferOverflowed {
                self.bufferProbeWindow(gated: gated,
                                       at: index,
                                       of: windows,
                                       rawRecordsWereEmpty: records.isEmpty,
                                       context: context)
                return
            }

            // F1 (review round 1): window membership. This branch is the forward walk and the
            // probe's buffer-overflow fallback. On the fallback the widened fetch returns the
            // previous day's records BEFORE their own window has run and the ledger cannot yet
            // know them — without this filter both days land in one batch anchored a day low
            // (rowless newest day on fresh installs, cross-row duplication on reinstall,
            // order-dependent batches). Records the next-older window will fetch are deferred
            // to it; records ONLY this window's span can return are kept. The forward walk
            // needs none of this: there the older window ran first and the ledger owns the
            // dedup.
            let windowBound: [[String: Any]]
            if context.backwardProbe, index + 1 < windows.count {
                let olderWindow = windows[index + 1]
                windowBound = gated.filter {
                    !Self.belongsToOlderProbeWindow($0, sensor: sensor, window: window, olderWindow: olderWindow)
                }
            } else {
                windowBound = gated
            }

            // D4 upload ledger: drop every record already enqueued by an earlier pass (widened
            // fetch span, rescan tail, travel overlap), so re-fetches cost no upload volume and
            // anchor instability is harmless.
            let ledger = self.storage.ledger(for: sensor, deviceKey: deviceKey)
            let filtered = SensorUploadLedger.filter(records: windowBound,
                                                     sensor: sensor,
                                                     windowDay: windowDay,
                                                     ledger: ledger)
            if filtered.nearDuplicateCount > 0 {
                // S7 re-fetch boundary drift, measured (D12) — never prevented (D13).
                self.analytics.track(event: .sensorNearDuplicate(sensor: sensor.shortSubsource,
                                                                 count: filtered.nearDuplicateCount))
            }
            if isRescanPass, !filtered.novel.isEmpty {
                // The D-D completion curve from the field: how late the OS writes a day.
                self.analytics.track(event: .sensorRescanNovel(sensor: sensor.shortSubsource,
                                                               device: deviceKey,
                                                               ageDays: windowAgeDays,
                                                               novelCount: filtered.novel.count))
            }

            if !filtered.novel.isEmpty {
                // Enqueue in batches bounded by record count AND serialized payload size, then
                // commit the fingerprints — ONLY once the batch is durably persisted (AC4): a
                // fingerprint committed for a record that never reached the queue would be lost
                // for good.
                let enqueued = self.enqueueRespectingPayloadLimit(Self.tagged(filtered.novel, with: context.device),
                                                                  windowStart: window.start,
                                                                  for: sensor)
                guard enqueued else {
                    self.analytics.track(event: .sensorDataBackfillReach(
                        sensor: context.device.telemetryName(for: sensor),
                        reachedBack: ISO8601DateFormatter().string(from: window.start),
                        boundedBy: BackfillLowerBound.Origin.enqueueFailed.rawValue))
                    self.handleWindowFailure(window: window, at: index, of: windows, context: context)
                    return
                }
                var updated = ledger
                filtered.newEntries.forEach { updated[$0.key] = $0.value }
                let pruneCutoff = Self.utcDayStart(context.now)
                    .addingTimeInterval(-Self.ledgerRetentionDays * Self.utcDay)
                self.storage.setLedger(SensorUploadLedger.pruned(updated, keepingDaysOnOrAfter: pruneCutoff),
                                       for: sensor,
                                       deviceKey: deviceKey)
                self.drainQueue(for: sensor)
            }

            if context.backwardProbe {
                // Only reached by the OVERFLOWED (as-you-go) probe: the buffering path returned
                // above. The empty-streak rule is shared with `bufferProbeWindow`.
                var next = context
                next.probeEmptyStreak = records.isEmpty ? context.probeEmptyStreak + 1 : 0
                if next.probeEmptyStreak >= Self.probeEmptyWindowStop {
                    // AC1: K consecutive confirmed-empty windows — everything older is beyond
                    // the OS retention horizon. The planned span is handled: park the cursor at
                    // the plan head, once (the buffer is empty here, so `finishProbe`'s flush
                    // is a no-op and only the terminal cursor write remains).
                    self.finishProbe(context: next)
                    return
                }
                self.processWindow(at: index + 1, of: windows, context: next)
                return
            }

            // Forward walk: the window is durably handled (enqueued, deduplicated, deliberately
            // filtered, or confirmed empty) — advance, monotonically, and move on. A rescan
            // window ends at or behind the stored cursor, so the monotonic write is what keeps
            // "cursors never rewind" true (the only sanctioned rewind stays `future_cursor`).
            self.advanceCursor(to: window.end, for: sensor, deviceKey: deviceKey)
            self.processWindow(at: index + 1, of: windows, context: context)
        }
    }

    /// Buffers one backward-probe window's records for the chronological flush (FUAM-3945
    /// round 4) and continues the walk. `windows[index]` is the window the records came from.
    /// Runs on `workQueue` only.
    private func bufferProbeWindow(gated: [[String: Any]],
                                   at index: Int,
                                   of windows: [DateInterval],
                                   rawRecordsWereEmpty: Bool,
                                   context: DeviceChainContext) {
        let sensor = context.sensor
        let window = windows[index]
        let windowDay = Self.utcDayStart(window.start)
        let isRescanPass = context.rescanBoundary.map { window.end <= $0 } ?? false
        let windowAgeDays = max(0, Int(Self.utcDayStart(context.now).timeIntervalSince(windowDay) / Self.utcDay))
        var next = context
        if !gated.isEmpty {
            // Read-only prefilter: a re-probe over already-uploaded days (crash recovery,
            // future_cursor reset) must not balloon the buffer with records the flush would
            // drop anyway. The authoritative filter re-runs at flush.
            let stored = self.storage.ledger(for: sensor, deviceKey: context.device.key)
            let novel = SensorUploadLedger.filter(records: gated,
                                                  sensor: sensor,
                                                  windowDay: windowDay,
                                                  ledger: stored).novel
            if !novel.isEmpty {
                let olderWindow = index + 1 < windows.count ? windows[index + 1] : nil
                next.probeBuffer.append(ProbeBufferedWindow(window: window,
                                                            olderWindow: olderWindow,
                                                            records: novel,
                                                            windowDay: windowDay,
                                                            isRescanPass: isRescanPass,
                                                            windowAgeDays: windowAgeDays))
                next.probeBufferRecordCount += novel.count
            }
        }
        next.probeEmptyStreak = rawRecordsWereEmpty ? context.probeEmptyStreak + 1 : 0
        if next.probeEmptyStreak >= Self.probeEmptyWindowStop {
            // AC1: K consecutive confirmed-empty windows — everything older is beyond the OS
            // retention horizon. Flush chronologically and park the cursor, once.
            self.finishProbe(context: next)
            return
        }
        if next.probeBufferRecordCount > self.probeBufferMaxRecords {
            // The cap: flush what is buffered now (chronological among themselves, NO cursor —
            // the probe is not done) and fall back to enqueue-as-you-go for the rest of the
            // walk, where the F1 membership filter is load-bearing again. Correctness is
            // unchanged; strict chronology across the whole probe is what is given up, and the
            // trace says so.
            self.analytics.track(event: .sensorDataBackfillReach(
                sensor: context.device.telemetryName(for: sensor),
                reachedBack: ISO8601DateFormatter().string(from: window.start),
                boundedBy: BackfillLowerBound.Origin.probeBufferOverflow.rawValue))
            guard self.flushProbeBuffer(context: next, assertGuardInert: false) else {
                // Retryable flush failure: abort this cycle's probe with no cursor written;
                // the next cycle re-probes and the ledger drops whatever already committed.
                self.nextDeviceChain(after: next)
                return
            }
            next.probeBuffer = []
            next.probeBufferRecordCount = 0
            next.probeBufferOverflowed = true
        }
        self.processWindow(at: index + 1, of: windows, context: next)
    }

    /// Terminal path of a backward probe (consent bound reached, or the empty-streak stop):
    /// flush the buffer OLDEST-first, then — only when every buffered window was durably
    /// handled — write the terminal cursor, once (AC1/AC4). Runs on `workQueue` only.
    private func finishProbe(context: DeviceChainContext) {
        if self.flushProbeBuffer(context: context, assertGuardInert: true), let head = context.planHeadEnd {
            self.advanceCursor(to: head, for: context.sensor, deviceKey: context.device.key)
        }
        self.nextDeviceChain(after: context)
    }

    /// Enqueues the probe's buffered windows in CHRONOLOGICAL order — oldest first, the same
    /// order the forward walk produces, so no code path enqueues out of chronological order
    /// (FUAM-3945 round 4). Per window: authoritative ledger filter (older windows of this very
    /// flush have already committed, which is what makes the F1 membership guard inert) →
    /// defensive membership guard → enqueue → fingerprint commit (AC4: only after the batch is
    /// durably persisted).
    ///
    /// Returns `false` on a retryable enqueue failure: the caller must NOT write the terminal
    /// cursor (the next sync cycle re-probes; re-fetched records that already committed are
    /// ledger-dropped). A window whose enqueue exhausts the per-window attempt budget is
    /// forfeited via `gave_up` — sanctioned, telemetered — and the flush continues.
    ///
    /// `assertGuardInert` is `true` only at the TERMINAL flush, where chronology is complete:
    /// anything the guard defers there is an ordering regression (or an OS fetch that defied
    /// the containment model) and must be loud in DEBUG. A mid-walk overflow flush runs before
    /// the older neighbours were fetched, so there the guard is legitimately load-bearing.
    /// Runs on `workQueue` only.
    private func flushProbeBuffer(context: DeviceChainContext, assertGuardInert: Bool) -> Bool {
        guard !context.probeBuffer.isEmpty else { return true }
        let sensor = context.sensor
        let deviceKey = context.device.key
        var forfeited = context.probeForfeitedWindowStarts
        var enqueuedAnything = false
        for buffered in context.probeBuffer.sorted(by: { $0.window.start < $1.window.start }) {
            let ledger = self.storage.ledger(for: sensor, deviceKey: deviceKey)
            let filtered = SensorUploadLedger.filter(records: buffered.records,
                                                     sensor: sensor,
                                                     windowDay: buffered.windowDay,
                                                     ledger: ledger)
            if buffered.isRescanPass, !filtered.novel.isEmpty {
                self.analytics.track(event: .sensorRescanNovel(sensor: sensor.shortSubsource,
                                                               device: deviceKey,
                                                               ageDays: buffered.windowAgeDays,
                                                               novelCount: filtered.novel.count))
            }
            var novel = filtered.novel
            var newEntries = filtered.newEntries
            var nearDuplicateFingerprints = filtered.nearDuplicateFingerprints
            if let older = buffered.olderWindow {
                var dropped: [[String: Any]] = []
                let kept = novel.filter { record in
                    guard Self.belongsToOlderProbeWindow(record,
                                                         sensor: sensor,
                                                         window: buffered.window,
                                                         olderWindow: older) else { return true }
                    dropped.append(record)
                    return false
                }
                if !dropped.isEmpty {
                    // The guard fired. Dropping is the right call in every case — these records
                    // would anchor THIS window's row a day low — but only an ordering
                    // regression should be loud. Two sanctioned causes are exempt (round 5):
                    // a forfeited (gave_up) older window's stragglers (the round-2 loss class,
                    // not a bug), and an S7 DRIFT TWIN — a re-fetched copy of an
                    // already-enqueued record whose period boundary drifted backwards across
                    // the window edge, which passes the ledger on its new fingerprint and
                    // legitimately satisfies the containment predicate.
                    let droppedFingerprints = Set(dropped.map { SensorUploadLedger.fingerprint(of: $0) })
                    let driftTwinCount = droppedFingerprints.intersection(nearDuplicateFingerprints).count
                    // `sensor_near_duplicate`'s contract is "still uploaded": a drifted twin
                    // the guard drops must not count (round 5, item 2).
                    nearDuplicateFingerprints.subtract(droppedFingerprints)
                    if assertGuardInert, !forfeited.contains(older.start), driftTwinCount != dropped.count {
                        assertionFailure("flushProbeBuffer: the F1 membership guard deferred "
                                         + "\(dropped.count - driftTwinCount) record(s) at the terminal flush "
                                         + "that are neither S7 drift twins nor a forfeited window's "
                                         + "stragglers — the chronological enqueue order has regressed (or "
                                         + "an OS fetch defied the containment model). Check the probe "
                                         + "flush ordering.")
                    }
                    if assertGuardInert {
                        // Round 5, item 3 (AC6/AC8): at the TERMINAL flush every window has
                        // already been fetched, so a guard drop is a real drop — it must be
                        // visible in Firebase, not only to the DEBUG assertion above. A
                        // mid-walk overflow flush is different: there the guard DEFERS records
                        // the older window will re-fetch itself, so nothing is lost or traced.
                        let reason: String
                        if forfeited.contains(older.start) {
                            reason = "probe_forfeited_window"
                        } else if driftTwinCount == dropped.count {
                            reason = "probe_drift_twin"
                        } else {
                            reason = "probe_guard_dropped"
                        }
                        self.analytics.track(event: .sensorRecordDropped(
                            sensor: context.device.telemetryName(for: sensor),
                            count: dropped.count,
                            reason: reason))
                    }
                    newEntries = newEntries.filter { !droppedFingerprints.contains($0.key) }
                    novel = kept
                }
            }
            if !nearDuplicateFingerprints.isEmpty {
                // S7 re-fetch boundary drift, measured (D12) — counted AFTER the membership
                // guard, so the count and the upload outcome agree (round 5, item 2).
                self.analytics.track(event: .sensorNearDuplicate(sensor: sensor.shortSubsource,
                                                                 count: nearDuplicateFingerprints.count))
            }
            guard !novel.isEmpty else { continue }
            let enqueued = self.enqueueRespectingPayloadLimit(Self.tagged(novel, with: context.device),
                                                              windowStart: buffered.window.start,
                                                              for: sensor)
            guard enqueued else {
                self.analytics.track(event: .sensorDataBackfillReach(
                    sensor: context.device.telemetryName(for: sensor),
                    reachedBack: ISO8601DateFormatter().string(from: buffered.window.start),
                    boundedBy: BackfillLowerBound.Origin.enqueueFailed.rawValue))
                let attemptKey = Self.attemptKey(context: context, window: buffered.window)
                let attempts = (self.windowFetchFailures[attemptKey] ?? 0) + 1
                guard attempts >= self.maxWindowFetchAttempts else {
                    self.windowFetchFailures[attemptKey] = attempts
                    return false
                }
                self.windowFetchFailures[attemptKey] = nil
                self.analytics.track(event: .sensorDataBackfillReach(
                    sensor: context.device.telemetryName(for: sensor),
                    reachedBack: ISO8601DateFormatter().string(from: buffered.window.end),
                    boundedBy: BackfillLowerBound.Origin.gaveUp.rawValue))
                forfeited.insert(buffered.window.start)
                continue
            }
            self.windowFetchFailures[Self.attemptKey(context: context, window: buffered.window)] = nil
            var updated = self.storage.ledger(for: sensor, deviceKey: deviceKey)
            newEntries.forEach { updated[$0.key] = $0.value }
            let pruneCutoff = Self.utcDayStart(context.now)
                .addingTimeInterval(-Self.ledgerRetentionDays * Self.utcDay)
            self.storage.setLedger(SensorUploadLedger.pruned(updated, keepingDaysOnOrAfter: pruneCutoff),
                                   for: sensor,
                                   deviceKey: deviceKey)
            enqueuedAnything = true
        }
        if enqueuedAnything {
            self.drainQueue(for: sensor)
        }
        return true
    }

    /// The give-up budget's dictionary key. Forward walk: per sensor+device — the failing window
    /// is always the head of the chain there (the cursor sits right below it), so one bucket is
    /// exact. Backward probe (round 2, found by the F8 test): per sensor+device+WINDOW — the
    /// probe re-fetches the NEWER windows before the failing one on every cycle, and their
    /// successes were wiping the shared counter, so a mid-plan poison window never exhausted its
    /// budget: the probe aborted every cycle for ever, the terminal cursor was never written and
    /// the whole backfill stalled silently. Probe windows are stable grid days, so the
    /// per-window key accumulates correctly across cycles.
    private static func attemptKey(context: DeviceChainContext, window: DateInterval) -> String {
        guard context.backwardProbe else { return context.failureKey }
        return "\(context.failureKey).\(window.start.timeIntervalSince1970)"
    }

    /// Shared AC4 failure policy for a window that was NOT durably handled (fetch error or
    /// enqueue/serialization failure): never advance the cursor for it. Retry on later sync
    /// cycles; after `maxWindowFetchAttempts` consecutive failures the window is abandoned —
    /// reported as `gave_up`, never silently (FUAM-3841). Runs on `workQueue` only.
    private func handleWindowFailure(window: DateInterval,
                                     at index: Int,
                                     of windows: [DateInterval],
                                     context: DeviceChainContext) {
        let sensor = context.sensor
        let attemptKey = Self.attemptKey(context: context, window: window)
        let attempts = (self.windowFetchFailures[attemptKey] ?? 0) + 1
        if attempts >= self.maxWindowFetchAttempts {
            self.windowFetchFailures[attemptKey] = nil
            #if DEBUG
            print("SensorSampleUploadManager - Giving up window [\(window.start) -> \(window.end)] "
                  + "for \(sensor.rawValue)/\(context.device.key) after \(attempts) attempts")
            #endif
            // Review fix #9 / AC4: a forfeited window is data loss — leave a telemetry trace,
            // not just a DEBUG print.
            let reachedBack = ISO8601DateFormatter().string(from: window.end)
            self.analytics.track(event: .sensorDataBackfillReach(sensor: context.device.telemetryName(for: sensor),
                                                                 reachedBack: reachedBack,
                                                                 boundedBy: BackfillLowerBound.Origin.gaveUp.rawValue))
            if context.backwardProbe {
                // Keep probing the older windows; the terminal cursor write covers the
                // abandoned window and the gave_up trace above is its loss record. The
                // empty-streak RESETS (F8): an unread window is UNKNOWN, not empty, and AC1's
                // stop criterion is K CONSECUTIVE confirmed-empties — two empties separated by
                // a gave-up window must not satisfy it. The forfeit is remembered (round 4) so
                // the flush neither uploads this day's stragglers into the newer window's row
                // nor mistakes their deferral for an ordering regression.
                var next = context
                next.probeEmptyStreak = 0
                next.probeForfeitedWindowStarts.insert(window.start)
                self.processWindow(at: index + 1, of: windows, context: next)
                return
            }
            // Forward walk: skip past the poison window so it cannot stall the chain.
            self.advanceCursor(to: window.end, for: sensor, deviceKey: context.device.key)
            self.processWindow(at: index + 1, of: windows, context: context)
        } else {
            self.windowFetchFailures[attemptKey] = attempts
            // Stop THIS DEVICE's chain for this cycle (the next sync retries it from its own
            // cursor — or re-probes, for a backfill) — but never the next device's: the cursors
            // are independent, so a Watch whose fetches keep failing must not cost the iPhone
            // its windows (FUAM-3945).
            self.scheduleRetry(for: sensor, attempt: attempts)
            self.nextDeviceChain(after: context)
        }
    }

    /// AC4/D3: cursors are strictly monotonic. A rescan window sits BEHIND the cursor by design
    /// and a backward probe hands windows over newest-first; writing such a window's end would
    /// rewind the cursor, and the only sanctioned rewind in the whole design is the
    /// `future_cursor` corruption reset (which writes the storage directly).
    private func advanceCursor(to date: Date, for sensor: SRSensor, deviceKey: String) {
        if let stored = self.storage.lastCursor(for: sensor, deviceKey: deviceKey), stored >= date {
            return
        }
        self.storage.setLastCursor(date, for: sensor, deviceKey: deviceKey)
    }

    /// Stamp every record with the device it was fetched from (FUAM-3945). Done here, once,
    /// rather than in each of the 11 mappers: one source of truth, and the value is by
    /// construction the same key the cursor and the telemetry use. The tags are additive
    /// free-form JSONB — no backend allow-list change, one subsource per sensor as before.
    static func tagged(_ records: [[String: Any]], with device: SensorDevice) -> [[String: Any]] {
        let tags = device.recordTags
        return records.map { $0.merging(tags) { _, tag in tag } }
    }

    // MARK: - Join-day gate & payload chunking (FUAM-3841, FUAM-3945)

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoPlainFormatter = ISO8601DateFormatter()

    private static func parseISO8601(_ string: String) -> Date? {
        return isoPlainFormatter.date(from: string) ?? isoFractionalFormatter.date(from: string)
    }

    /// The three usage reports whose documented `duration` IS the span the report covers, so a
    /// period start can be derived from it. `SRKeyboardMetrics.duration` is deliberately NOT in
    /// this set: it is cumulative typing/session time (minutes), not a report period, and
    /// subtracting it from `recorded_at` put a whole pre-consent day of keyboard metrics back
    /// inside the bound (review round 3, C1).
    static let usageReportSensors: Set<SRSensor> = [.deviceUsageReport, .phoneUsageReport, .messagesUsageReport]

    /// Shortest `duration_s` still plausible as a usage-report span. Anything shorter — and
    /// absent, zero or negative — is not a period length and must not be turned into one.
    static let minimumPlausibleReportSpan: TimeInterval = 3600

    /// The MEASUREMENT time of a mapped record (the start of the period it describes), or `nil`
    /// when the record does not carry one — in which case it is undecidable and only
    /// `windowVouches(for:windowStart:lowerBound:)` can save it.
    ///
    /// `recorded_at` is `SRFetchResult.timestamp`: WHEN SENSORKIT WROTE the record. It is a write
    /// time for every client-push sensor and is never read as a measurement time here (review
    /// round 3, C2) — production data for `.visits` shows seven records sharing one `recorded_at`
    /// while the visits themselves span three earlier days.
    ///
    /// Where each mapper actually puts the measurement time (audited in review round 3):
    ///
    /// | sensor | measurement time in the emitted record |
    /// | --- | --- |
    /// | `accelerometer` | `t` (`CMRecordedAccelerometerData.startDate`) |
    /// | `ambientLightSensor` / `ambientPressure` / `rotationRate` | `t` (KVC `startDate` or
    ///   `timestamp`; `distantPast` when unresolvable, which fails the gate — the safe direction) |
    /// | `pedometerData` | `start_ms` (`CMPedometerData.startDate`) |
    /// | `visits` | nested `arrival.start`, else nested `departure.start` |
    /// | `deviceUsageReport` / `phoneUsageReport` / `messagesUsageReport` | `start` when the OS
    ///   exposes `startDate`, else `recorded_at − duration_s` for a plausible span |
    /// | `keyboardMetrics` | `start` when the OS exposes `startDate`, otherwise NONE |
    /// | `mediaEvents` | NONE — `SRMediaEvent` exposes no date at all, only `eventType` / `mediaIdentifier` |
    static func measurementTime(of record: [String: Any], sensor: SRSensor) -> Date? {
        if let startMs = record["start_ms"] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
        }
        for key in ["t", "start"] {
            if let string = record[key] as? String, let date = Self.parseISO8601(string) {
                return date
            }
        }
        if sensor == .visits {
            return Self.nestedStart(in: record, key: "arrival") ?? Self.nestedStart(in: record, key: "departure")
        }
        guard Self.usageReportSensors.contains(sensor),
              let duration = (record["duration_s"] as? NSNumber)?.doubleValue,
              duration >= Self.minimumPlausibleReportSpan,
              let recordedAtString = record["recorded_at"] as? String,
              let recordedAt = Self.parseISO8601(recordedAtString) else { return nil }
        return recordedAt.addingTimeInterval(-duration)
    }

    /// `{"start": ISO8601, "end": ISO8601}` under `key` — the shape `VisitsMapper` emits for
    /// `arrival` / `departure`.
    private static func nestedStart(in record: [String: Any], key: String) -> Date? {
        guard let nested = record[key] as? [String: Any],
              let start = nested["start"] as? String else { return nil }
        return Self.parseISO8601(start)
    }

    /// Whether the fetch window can vouch for a record whose measurement time is undecidable —
    /// i.e. whether SensorKit indexes that sensor by measurement time:
    ///
    /// - continuous sensors (accelerometer, ambient light/pressure, rotation, pedometer, media
    ///   events): the fetch window IS a measurement-time window, so one opening at or after the
    ///   bound cannot contain pre-consent data;
    /// - the four day-aggregated report sensors are indexed by WRITE time, and a report written
    ///   during the first window describes the previous, pre-consent day — so the window vouches
    ///   only when it opens STRICTLY above the bound (one window of write lag allowed);
    /// - `.visits` is indexed by write time with a lag of DAYS (production: one `recorded_at`,
    ///   arrivals spanning three earlier days), so the window never vouches — a visit with
    ///   neither `arrival` nor `departure` is always dropped.
    ///
    /// ponytail: the report allowance is one window (a day) of write lag. A report written more
    /// than a day late and describing a pre-join day still passes; tighten by requiring
    /// `windowStart > lowerBound + lag` if field data shows later writes.
    static func windowVouches(for sensor: SRSensor, windowStart: Date, lowerBound: Date) -> Bool {
        if sensor == .visits { return false }
        return Self.dayAggregatedSensors.contains(sensor) ? windowStart > lowerBound : windowStart >= lowerBound
    }

    /// Hard client-side consent gate: never enqueue (hence never transmit) a record measured
    /// before the backfill lower bound (`BackfillLowerBound`), independently of any server-side
    /// validation. The bound is never optional — an unknown join day resolves to `now`
    /// (forward-only), under which no historical record can survive this filter.
    ///
    /// Records with no readable measurement time are kept ONLY when the fetch window itself
    /// vouches for them (see `windowVouches`). `windowStart` must therefore be the REAL window
    /// the records came from, both at enqueue time and at drain time.
    static func dropPreBoundRecords(_ records: [[String: Any]],
                                    lowerBound: Date,
                                    windowStart: Date,
                                    sensor: SRSensor) -> [[String: Any]] {
        let windowFullyInBounds = Self.windowVouches(for: sensor, windowStart: windowStart, lowerBound: lowerBound)
        return records.filter { record in
            guard let measured = Self.measurementTime(of: record, sensor: sensor) else {
                return windowFullyInBounds
            }
            return measured >= lowerBound
        }
    }

    /// Enqueue records in batches that respect both the record-count cap and the server's
    /// 10 MB request limit (oversized batches are bisected until they serialize below
    /// `maxBatchBytes`). Returns `false` when ANY batch failed to persist (AC4): the caller
    /// must then treat the whole window as not durably handled and leave the cursor alone.
    private func enqueueRespectingPayloadLimit(_ records: [[String: Any]],
                                               windowStart: Date,
                                               for sensor: SRSensor) -> Bool {
        return Self.splitRespectingPayloadLimit(records, maxBatchSize: maxBatchSize, maxBatchBytes: maxBatchBytes)
            .allSatisfy { self.storage.enqueueBatch($0, windowStart: windowStart, for: sensor) }
    }

    /// Pure batch splitting (internal for unit tests): caps batches at `maxBatchSize` records,
    /// then bisects any batch whose serialized JSON exceeds `maxBatchBytes`. A single record
    /// is never split further (terminates), and record order is preserved.
    static func splitRespectingPayloadLimit(_ records: [[String: Any]],
                                            maxBatchSize: Int,
                                            maxBatchBytes: Int) -> [[[String: Any]]] {
        var batches: [[[String: Any]]] = []
        func appendBisectingIfTooLarge(_ batch: [[String: Any]]) {
            if batch.count > 1, Self.serializedSize(of: batch) > maxBatchBytes {
                let half = batch.count / 2
                appendBisectingIfTooLarge(Array(batch[..<half]))
                appendBisectingIfTooLarge(Array(batch[half...]))
            } else {
                batches.append(batch)
            }
        }
        var index = 0
        while index < records.count {
            let end = min(index + maxBatchSize, records.count)
            appendBisectingIfTooLarge(Array(records[index..<end]))
            index = end
        }
        return batches
    }

    // ponytail: serializes the batch once per bisection level — fine for ≤500-record
    // batches; revisit only if profiling shows enqueue cost.
    private static func serializedSize(of batch: [[String: Any]]) -> Int {
        guard JSONSerialization.isValidJSONObject(batch),
              let data = try? JSONSerialization.data(withJSONObject: batch) else { return 0 }
        return data.count
    }

    /// Uploads queued batches. The cursor is NEVER touched here (review fix #3): it is owned
    /// by the window pipeline (`handleWindowResult`), which only ever advances it to the END
    /// of a window whose batches were actually enqueued. Deriving a cursor write from
    /// wall-clock `Date()` on the retry path silently forfeited every pending window.
    func drainQueue(for sensor: SRSensor, attempt: Int = 1) {
        guard reachability.isReachable else { return }
        // If there is nothing to upload, do not require a delegate
        if storage.pendingBatchCount(for: sensor) == 0 { return }

        // Review fix #2: with no join day nothing may be transmitted, but the queue is left
        // untouched — a temporarily unavailable user record must not destroy legitimate
        // queued data. The next drain, once the join day resolves, filters and ships it.
        let bound = self.currentBound
        guard !bound.isForwardOnly else {
            #if DEBUG
            print("SensorSampleUploadManager - Holding \(sensor.rawValue) queue: no join day")
            #endif
            return
        }

        guard let net = networkDelegate else {
            #if DEBUG
            print("SensorSampleUploadManager - Network delegate not set; postponing upload")
            #endif
            return
        }

        // Recursive, non-blocking upload
        func uploadNextBatch() {
            // Always run on our background queue
            workQueue.async { [weak self] in
                guard let self = self else { return }

                guard let batch = self.storage.dequeueNextBatch(for: sensor) else {
                    return // queue drained
                }

                // Review fix #2: the persisted queue outlives the policy that filled it (an
                // offline queue built by an older build, or before the join day resolved), so
                // the consent gate runs again immediately before the bytes leave the device.
                // It runs with the batch's OWN window start (review round 3, I1) — standing
                // `.distantPast` in for it made every undecidable record fail the gate, and
                // since only the filtered batch is ever re-enqueued that loss was permanent.
                let uploadable = Self.dropPreBoundRecords(batch.records,
                                                          lowerBound: bound.date,
                                                          windowStart: batch.windowStart,
                                                          sensor: sensor)
                if uploadable.count != batch.records.count {
                    // Dropping at drain time is data loss by design, but it must never be
                    // invisible: a sensor silently losing 100% of its records (e.g. a future OS
                    // stops emitting the key the gate reads) has to show up in telemetry.
                    self.analytics.track(
                        event: .sensorDataBackfillReach(sensor: sensor.shortSubsource,
                                                        reachedBack: ISO8601DateFormatter().string(from: batch.windowStart),
                                                        boundedBy: BackfillLowerBound.Origin.drainFiltered.rawValue))
                }
                guard !uploadable.isEmpty else {
                    #if DEBUG
                    print("SensorSampleUploadManager - Dropped a fully out-of-bounds queued batch for \(sensor.rawValue)")
                    #endif
                    uploadNextBatch()
                    return
                }

                net.uploadSensorBatch(sensor: sensor, payload: uploadable)
                    .subscribe(
                        onSuccess: { [weak self] in
                            guard let self = self else { return }
                            // If more batches remain, keep going
                            if self.storage.pendingBatchCount(for: sensor) > 0 {
                                uploadNextBatch()
                            }
                        },
                        onFailure: { [weak self] error in
                            guard let self = self else { return }
                            #if DEBUG
                            print("SensorSampleUploadManager - Upload failed for \(sensor.rawValue): \(error)")
                            #endif
                            // Hop onto the work queue: `batchUploadRejections` is mutated there
                            // only, and this callback arrives on an arbitrary Rx thread.
                            self.workQueue.async { [weak self] in
                                guard let self = self else { return }
                                // FUAM-3945 round 5 (AC6): only a PERMANENT rejection burns the
                                // batch's upload budget — a network outage or server error stays
                                // on the unbounded backoff retry below. On exhaustion the batch
                                // is dropped (it is already dequeued: not re-enqueueing IS the
                                // drop), reported, and the drain moves on so it cannot shadow
                                // the batches queued behind it.
                                if let uploadError = error as? SensorUploadError,
                                   case .permanentlyRejected(let statusCode) = uploadError {
                                    let key = Self.batchRejectionKey(sensor: sensor,
                                                                     windowStart: batch.windowStart,
                                                                     records: uploadable)
                                    let rejections = (self.batchUploadRejections[key] ?? 0) + 1
                                    guard rejections < self.maxBatchUploadRejections else {
                                        self.batchUploadRejections[key] = nil
                                        self.analytics.track(event: .sensorDataBackfillReach(
                                            sensor: sensor.shortSubsource,
                                            reachedBack: ISO8601DateFormatter().string(from: batch.windowStart),
                                            boundedBy: BackfillLowerBound.Origin.uploadStuck.rawValue))
                                        self.analytics.track(event: .sensorRecordDropped(
                                            sensor: sensor.shortSubsource,
                                            count: uploadable.count,
                                            reason: "upload_rejected_\(statusCode)"))
                                        uploadNextBatch()
                                        return
                                    }
                                    self.batchUploadRejections[key] = rejections
                                }
                                // Re-enqueue the FILTERED batch (dropped records must not come
                                // back) and schedule a retry with backoff. A failed re-persist
                                // is unrecoverable at this point — the batch is already
                                // dequeued, the cursor long advanced and the fingerprints
                                // committed — but it must never be SILENT (review round 1,
                                // F7 / AC6): the enqueue_failed trace is what distinguishes
                                // "lost to a storage failure" from "never collected".
                                if !self.storage.enqueueBatch(uploadable, windowStart: batch.windowStart, for: sensor) {
                                    self.analytics.track(event: .sensorDataBackfillReach(
                                        sensor: sensor.shortSubsource,
                                        reachedBack: ISO8601DateFormatter().string(from: batch.windowStart),
                                        boundedBy: BackfillLowerBound.Origin.enqueueFailed.rawValue))
                                }
                                self.scheduleRetry(for: sensor, attempt: attempt + 1)
                            }
                        }
                    )
                    .disposed(by: self.disposeBag)
            }
        }

        uploadNextBatch()
    }

    /// Identity of a queued batch across drain retries (FUAM-3945 round 5). Stable because the
    /// re-enqueued content is the drain-FILTERED record set, which the gate reproduces
    /// byte-identically on the next pass under the same bound. A key collision (two batches of
    /// the same window, count and head record) would only merge two budgets — never lose the
    /// drop trace. A bound shift changes the key and refunds the budget: the safe direction.
    private static func batchRejectionKey(sensor: SRSensor, windowStart: Date, records: [[String: Any]]) -> String {
        let head = records.first.map { SensorUploadLedger.fingerprint(of: $0) } ?? "empty"
        return "\(sensor.rawValue).\(windowStart.timeIntervalSince1970).\(records.count).\(head)"
    }

    // MARK: - Retry

    private func scheduleRetry(for sensor: SRSensor, attempt: Int) {
        // Serialize retryWorkItems mutations on the work queue (review fix #10 — this is
        // reached from Rx upload callbacks on arbitrary threads).
        workQueue.async { [weak self] in
            guard let self else { return }
            // Cancel previous retry if any
            self.retryWorkItems[sensor]?.cancel()

            let delay = min(self.retryMaxDelay, self.retryBaseDelay * pow(2.0, Double(max(0, attempt - 1))))
            let work = DispatchWorkItem { [weak self] in
                self?.drainQueue(for: sensor, attempt: attempt)
            }
            self.retryWorkItems[sensor] = work
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: work)
        }
    }
    
    /// FUAM-3844 (hardening): clearance false while at least one configured sensor is
    /// OS-authorized is always a bug — the participant granted the sensor but the SDK
    /// refuses to collect (this silent combination is why FUAM-3835 ran undetected).
    private func trackClearanceMismatchIfNeeded(reason: String) {
        let authorized = sensors.filter { isAuthorized($0) }
        guard !authorized.isEmpty else { return }
        let sensorNames = authorized.map { $0.shortSubsource }.joined(separator: ",")
        analytics.track(event: .sensorDataClearanceMismatch(reason: reason, authorizedSensors: sensorNames))
    }

    private func purgeAllData(reason: String) {
        #if DEBUG
        print("SensorSampleUploadManager - Purging pending data (\(reason))")
        #endif

        // Stop pending retries
        retryWorkItems.values.forEach { $0.cancel() }
        retryWorkItems.removeAll()
        windowFetchFailures.removeAll()
        batchUploadRejections.removeAll()

        // Drop ALL queued batches. The cursor is deliberately NOT fast-forwarded (FUAM-3844):
        // dropping queued batches on clearance loss is correct; forfeiting the ability to
        // re-fetch that window is not. FUAM-3841 builds on this.
        for sensor in sensors {
            // Dequeue until the queue is empty
            while storage.dequeueNextBatch(for: sensor) != nil { /* drop */ }
            // The ledger goes WITH the queue (D4): a purged batch was never uploaded, so its
            // fingerprints must not survive to suppress a legitimate re-collection.
            storage.purgeLedger(for: sensor)
        }
    }
}

// MARK: - Deletion-record probe (FUAM-3945, C1 item 9 — telemetry only)

/// One `SRFetchRequest` whose only interest is the `SRDeletionRecord`s in the range: the OS's
/// own statement that data in a span was deleted and why. Regular samples are ignored (the
/// pipeline's mappers own those). The reader is its own delegate holder; the manager retains
/// the probe until the fetch completes or fails.
final class SensorDeletionRecordProbe: NSObject, SRSensorReaderDelegate {

    struct Deletion {
        let start: Date
        let end: Date
        let reason: String
    }

    private let reader: SRSensorReader
    private let lock = NSLock()
    private var collected: [Deletion] = []
    private var completion: (([Deletion]) -> Void)?

    init(sensor: SRSensor) {
        self.reader = SRSensorReader(sensor: sensor)
        super.init()
    }

    func start(from: Date, to: Date, device: SensorDevice, completion: @escaping ([Deletion]) -> Void) {
        self.lock.lock()
        self.completion = completion
        self.lock.unlock()
        self.reader.delegate = self
        let request = SRFetchRequest()
        request.device = device.fetchTarget
        request.from = from.srAbsoluteTime
        request.to = to.srAbsoluteTime
        self.reader.fetch(request)
    }

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {
        if let deletion = result.sample as? SRDeletionRecord {
            let record = Deletion(start: Date(timeIntervalSinceReferenceDate: deletion.startTime.toCFAbsoluteTime()),
                                  end: Date(timeIntervalSinceReferenceDate: deletion.endTime.toCFAbsoluteTime()),
                                  reason: Self.reasonName(deletion.reason))
            self.lock.lock()
            self.collected.append(record)
            self.lock.unlock()
        }
        return true
    }

    func sensorReader(_ reader: SRSensorReader, didCompleteFetch fetchRequest: SRFetchRequest) {
        self.finish()
    }

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      failedWithError error: Error) {
        // Best-effort telemetry: deliver whatever was collected before the failure.
        self.finish()
    }

    private func finish() {
        self.lock.lock()
        let completion = self.completion
        self.completion = nil
        let deletions = self.collected
        self.lock.unlock()
        completion?(deletions)
    }

    static func reasonName(_ reason: SRDeletionReason) -> String {
        switch reason {
        case .userInitiated: return "user_initiated"
        case .lowDiskSpace: return "low_disk_space"
        case .ageLimit: return "age_limit"
        case .noInterestedClients: return "no_interested_clients"
        case .systemInitiated: return "system_initiated"
        @unknown default: return "unknown_\(reason.rawValue)"
        }
    }
}

// MARK: - Upload ledger (FUAM-3945, D4)

/// Client-side record idempotency. The server upserts one row per
/// `(identity, source, subsource, min(records[].recorded_at))` and deduplicates only WITHIN a
/// row, so a re-fetch whose first record drifted by a minute would land a whole duplicate day in
/// a new row — and no backend change is allowed. The ledger makes the RECORDS idempotent
/// instead: every record ever durably enqueued is fingerprinted, and later passes (widened
/// fetch span D1, rescan tail D3, travel overlap) upload only what is genuinely novel, so
/// anchor instability becomes harmless.
///
/// The fingerprint's whole value collapses silently if it is not byte-stable across two fetches
/// of identical data, so the serialization is CANONICAL by construction: keys sorted, arrays in
/// order, deterministic integer/float/bool/date rendering (no `Double.description`, no locale,
/// no dictionary iteration order), NFC-agnostic byte-wise string escaping. `1` and `1.0` render
/// identically on purpose — NSNumber boxing must not change a record's identity.
enum SensorUploadLedger {

    struct FilterResult {
        /// Records never seen before, in their original order — the only ones to enqueue.
        let novel: [[String: Any]]
        /// Ledger entries for `novel`, to commit once the batch is durably persisted (AC4).
        let newEntries: [String: SensorLedgerEntry]
        /// Records dropped because their fingerprint was already in the ledger (or duplicated
        /// within this very batch).
        let duplicateCount: Int
        /// Fingerprints of novel records whose measurement period OVERLAPS one already in the
        /// ledger: SensorKit re-fetch boundary drift (S7). They are still uploaded — suppressing
        /// either side would lose data — but counted, so the drift rate is a measured quantity
        /// (D12/D13). Fingerprints rather than a bare count (round 5, item 2) so the terminal
        /// probe flush can (a) exempt a drifted twin from the ordering-regression assertion and
        /// (b) keep `sensor_near_duplicate` in agreement with what was actually uploaded when
        /// the membership guard drops one.
        let nearDuplicateFingerprints: Set<String>

        var nearDuplicateCount: Int { return self.nearDuplicateFingerprints.count }
    }

    /// Splits `records` into novel vs already-enqueued. Pure.
    static func filter(records: [[String: Any]],
                       sensor: SRSensor,
                       windowDay: Date,
                       ledger: [String: SensorLedgerEntry]) -> FilterResult {
        var novel: [[String: Any]] = []
        var newEntries: [String: SensorLedgerEntry] = [:]
        var duplicates = 0
        var nearDuplicates: Set<String> = []
        for record in records {
            let fingerprint = Self.fingerprint(of: record)
            guard ledger[fingerprint] == nil, newEntries[fingerprint] == nil else {
                duplicates += 1
                continue
            }
            let period = Self.period(of: record, sensor: sensor)
            if let period = period {
                let overlapsExisting = ledger.values.contains { entry in
                    guard let start = entry.periodStart, let end = entry.periodEnd else { return false }
                    return period.start < end && start < period.end
                }
                if overlapsExisting { nearDuplicates.insert(fingerprint) }
            }
            novel.append(record)
            newEntries[fingerprint] = SensorLedgerEntry(day: windowDay,
                                                        periodStart: period?.start,
                                                        periodEnd: period?.end)
        }
        return FilterResult(novel: novel,
                            newEntries: newEntries,
                            duplicateCount: duplicates,
                            nearDuplicateFingerprints: nearDuplicates)
    }

    /// Drops entries whose window day fell behind `cutoff` — the rescan horizon plus margin.
    /// Over-pruning only costs a re-upload the server union-merges into the same row.
    static func pruned(_ ledger: [String: SensorLedgerEntry],
                       keepingDaysOnOrAfter cutoff: Date) -> [String: SensorLedgerEntry] {
        return ledger.filter { $0.value.day >= cutoff }
    }

    /// SHA-256 over the canonical serialization, truncated to 16 bytes, hex-encoded.
    static func fingerprint(of record: [String: Any]) -> String {
        let digest = SHA256.hash(data: Data(Self.canonical(record).utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    /// The measurement period of a record, when one is derivable: only the three usage reports,
    /// whose documented `duration_s` IS the span the report covers. Used solely for the
    /// near-duplicate telemetry — never for identity, never for control flow.
    private static func period(of record: [String: Any], sensor: SRSensor) -> (start: Date, end: Date)? {
        guard SensorSampleUploadManager.usageReportSensors.contains(sensor),
              let start = SensorSampleUploadManager.measurementTime(of: record, sensor: sensor),
              let duration = (record["duration_s"] as? NSNumber)?.doubleValue,
              duration >= SensorSampleUploadManager.minimumPlausibleReportSpan else { return nil }
        return (start, start.addingTimeInterval(duration))
    }

    // MARK: Canonical serialization

    /// Deterministic textual form of a JSON-ready value. Internal for the determinism specs.
    static func canonical(_ value: Any) -> String {
        switch value {
        case let dictionary as [String: Any]:
            let body = dictionary.keys.sorted()
                .map { "\(Self.escaped($0)):\(Self.canonical(dictionary[$0] ?? NSNull()))" }
                .joined(separator: ",")
            return "{" + body + "}"
        case let array as [Any]:
            return "[" + array.map { Self.canonical($0) }.joined(separator: ",") + "]"
        case let string as String:
            return Self.escaped(string)
        case let date as Date:
            // Mappers emit ISO strings, so a raw Date here is defensive: epoch milliseconds,
            // integer — never a formatter, never a locale.
            return String(Int64((date.timeIntervalSince1970 * 1000).rounded()))
        case let number as NSNumber:
            return Self.canonical(number: number)
        case is NSNull:
            return "null"
        default:
            // Records are JSON-serializable by contract (they go through JSONSerialization at
            // upload); anything else is a programming error, rendered stably enough not to trap.
            assertionFailure("SensorUploadLedger - non-JSON value in a record: \(type(of: value))")
            return Self.escaped(String(describing: value))
        }
    }

    /// NSNumber rendering that does not depend on how the value was boxed: booleans as
    /// `true`/`false` (a CFBoolean is NOT the integer 1), integral floats as integers (`1.0`
    /// and `1` are the same logical value), other floats via `%.17g` in the POSIX locale
    /// (round-trip exact, locale-immune — never `Double.description`).
    private static func canonical(number: NSNumber) -> String {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        switch String(cString: number.objCType) {
        case "f", "d":
            let value = number.doubleValue
            if value.rounded(.towardZero) == value, abs(value) < 9_007_199_254_740_992 {
                return String(Int64(value))
            }
            return String(format: "%.17g", locale: Locale(identifier: "en_US_POSIX"), value)
        case "Q":
            return String(number.uint64Value)
        default:
            return String(number.int64Value)
        }
    }

    /// JSON-style string escaping, byte-wise over unicode scalars: no locale, no NSString
    /// bridging surprises.
    private static func escaped(_ string: String) -> String {
        var out = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

// SensorNetworkBridge.swift

/// Adapts SensorKitManagerNetworkDelegate -> SensorSampleUploaderNetworkDelegate
final class SensorNetworkBridge: SensorSampleUploaderNetworkDelegate {

    // Keep a weak ref to avoid retain cycles
    private weak var adapter: SensorKitManagerNetworkDelegate?

    init(adapter: SensorKitManagerNetworkDelegate) {
        self.adapter = adapter
    }

    func uploadSensorBatch(sensor: SRSensor, payload: [[String: Any]]) -> Single<Void> {
        // Shape data so that 'subsource' becomes the sensor rawValue (e.g. "accelerometer")
        let body: [String: Any] = [
            "sensor": sensor.shortSubsource,
            "records": payload
        ]
        return adapter?.uploadSensorNetworkData(body, source: "sensor_kit")
            .map { _ in () }
            ?? .error(NSError(domain: "net.bridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing adapter"]))
    }
}
