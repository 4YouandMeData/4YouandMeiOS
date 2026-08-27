//
//  SensorSampleUploadManager.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

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
        return Self.buildWindowPlan(now: min(now, ServerClock.now()),
                                    boundNow: max(now, ServerClock.now()),
                                    joinDay: clearanceDelegate?.enrollmentDate,
                                    cursor: storage.lastCursor(for: sensor, deviceKey: device.key),
                                    embargo: max(sensorkitEmbargo, device.syncHoldback))
    }

    /// One UTC calendar day. UTC has no DST, so every UTC day is exactly 86400 seconds and a
    /// day boundary is plain arithmetic — no `Calendar`, hence no way for the device timezone to
    /// leak into the plan.
    static let utcDay: TimeInterval = 24 * 60 * 60

    /// Start of the UTC calendar day containing `date`.
    static func utcDayStart(_ date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: (seconds / Self.utcDay).rounded(.down) * Self.utcDay)
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
    static func buildWindowPlan(now: Date,
                                boundNow: Date,
                                joinDay: Date?,
                                cursor: Date?,
                                embargo: TimeInterval) -> WindowPlan {
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

        guard from < safeTo else {
            return WindowPlan(windows: [], lowerBound: from, lowerBoundOrigin: origin, consentBound: lowerBound)
        }

        var windows: [DateInterval] = []
        var start = from
        // Migration window: [cursor, next UTC midnight). Skipped when `from` is already aligned
        // (steady state) and when the partial day is not complete yet — in which case `start`
        // moves past `safeTo` and the loop below plans nothing, exactly as intended.
        if start != Self.utcDayStart(start) {
            let boundary = Self.utcDayStart(start).addingTimeInterval(Self.utcDay)
            if boundary <= safeTo {
                windows.append(DateInterval(start: start, end: boundary))
            }
            start = boundary
        }
        while start.addingTimeInterval(Self.utcDay) <= safeTo {
            let end = start.addingTimeInterval(Self.utcDay)
            windows.append(DateInterval(start: start, end: end))
            start = end
        }

        return WindowPlan(windows: windows, lowerBound: from, lowerBoundOrigin: origin, consentBound: lowerBound)
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

        /// `"<sensor>.<deviceKey>"` — failure and empty-plan counters are per sensor AND device.
        var failureKey: String { return "\(self.sensor.rawValue).\(self.device.key)" }
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
        let context = DeviceChainContext(sensor: sensor,
                                         device: device,
                                         devices: devices,
                                         deviceIndex: index,
                                         now: now,
                                         mapper: mapper,
                                         plannedBound: plan.consentBound)
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
              + "from \(firstWindow.start) (bounded by \(plan.lowerBoundOrigin.rawValue))")
        #endif

        processWindow(at: 0, of: plan.windows, context: context)
    }

    /// Sequentially process each window to respect mapper's "no concurrent fetch" precondition.
    private func processWindow(at index: Int, of windows: [DateInterval], context: DeviceChainContext) {
        guard index < windows.count else {
            // This device is done: hand the mapper over to the next one (FUAM-3945).
            self.nextDeviceChain(after: context)
            return
        }

        let window = windows[index]
        context.mapper.fetchAndMap(from: window.start, to: window.end, device: context.device) { [weak self] result in
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
            // FUAM-3841: one poison window must not stall the per-sensor chain forever.
            // Retry on subsequent sync cycles (cursor untouched); after
            // `maxWindowFetchAttempts` consecutive failures (per sensor — the failing window
            // is always the head of the chain, review fix #5), skip it (advance the cursor
            // past it, forfeiting that window) and move on.
            let attempts = (self.windowFetchFailures[context.failureKey] ?? 0) + 1
            if attempts >= self.maxWindowFetchAttempts {
                self.windowFetchFailures[context.failureKey] = nil
                #if DEBUG
                print("SensorSampleUploadManager - Giving up window [\(window.start) -> \(window.end)] "
                      + "for \(sensor.rawValue)/\(context.device.key) after \(attempts) attempts")
                #endif
                // Review fix #9: a forfeited window is data loss — leave a telemetry trace,
                // not just a DEBUG print.
                let reachedBack = ISO8601DateFormatter().string(from: window.end)
                self.analytics.track(event: .sensorDataBackfillReach(sensor: context.device.telemetryName(for: sensor),
                                                                     reachedBack: reachedBack,
                                                                     boundedBy: BackfillLowerBound.Origin.gaveUp.rawValue))
                self.storage.setLastCursor(window.end, for: sensor, deviceKey: context.device.key)
                self.processWindow(at: index + 1, of: windows, context: context)
            } else {
                self.windowFetchFailures[context.failureKey] = attempts
                // Stop THIS DEVICE's chain for this cycle (the next sync retries it from its own
                // cursor) — but never the next device's: the cursors are independent, so a Watch
                // whose fetches keep failing must not cost the iPhone its windows (FUAM-3945).
                self.scheduleRetry(for: sensor, attempt: attempts)
                self.nextDeviceChain(after: context)
            }

        case .success(let records):
            self.windowFetchFailures[context.failureKey] = nil

            // Hard consent gate: drop anything measured before the backfill lower bound,
            // regardless of what SensorKit returned for the requested window.
            let uploadable = Self.dropPreBoundRecords(records,
                                                      lowerBound: boundDate,
                                                      windowStart: window.start,
                                                      sensor: sensor)

            if uploadable.isEmpty {
                // Advance cursor even if empty to avoid refetching the same day/chunk again.
                self.storage.setLastCursor(window.end, for: sensor, deviceKey: context.device.key)
                // Move to next window
                self.processWindow(at: index + 1, of: windows, context: context)
                return
            }

            // Enqueue in batches bounded by record count AND serialized payload size.
            self.enqueueRespectingPayloadLimit(Self.tagged(uploadable, with: context.device),
                                               windowStart: window.start,
                                               for: sensor)

            // === Cursor advancement policy ===
            // "At-least-once" (simple): advance now; queued batches will be retried until uploaded.
            self.storage.setLastCursor(window.end, for: sensor, deviceKey: context.device.key)

            self.drainQueue(for: sensor)

            // Next window
            self.processWindow(at: index + 1, of: windows, context: context)
        }
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
    /// `maxBatchBytes`).
    private func enqueueRespectingPayloadLimit(_ records: [[String: Any]],
                                               windowStart: Date,
                                               for sensor: SRSensor) {
        Self.splitRespectingPayloadLimit(records, maxBatchSize: maxBatchSize, maxBatchBytes: maxBatchBytes)
            .forEach { self.storage.enqueueBatch($0, windowStart: windowStart, for: sensor) }
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
                            // Re-enqueue the FILTERED batch (dropped records must not come back)
                            // and schedule a retry with backoff.
                            self.storage.enqueueBatch(uploadable, windowStart: batch.windowStart, for: sensor)
                            #if DEBUG
                            print("SensorSampleUploadManager - Upload failed for \(sensor.rawValue): \(error)")
                            #endif
                            self.scheduleRetry(for: sensor, attempt: attempt + 1)
                        }
                    )
                    .disposed(by: self.disposeBag)
            }
        }

        uploadNextBatch()
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

        // Drop ALL queued batches. The cursor is deliberately NOT fast-forwarded (FUAM-3844):
        // dropping queued batches on clearance loss is correct; forfeiting the ability to
        // re-fetch that window is not. FUAM-3841 builds on this.
        for sensor in sensors {
            // Dequeue until the queue is empty
            while storage.dequeueNextBatch(for: sensor) != nil { /* drop */ }
        }
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
