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

    /// Minimum time between auto-sync cycles (avoid noisy triggers).
    private let minSyncInterval: TimeInterval = 15 // 15 minutes

    /// Exponential backoff boundaries for retry.
    private let retryBaseDelay: TimeInterval = 30
    private let retryMaxDelay: TimeInterval = 15 * 60
    
    private let sensorkitEmbargo: TimeInterval = 24 * 60 * 60   // 24h absolute duration

    /// How far back the client trusts the OS to still hold SensorKit data.
    ///
    /// ⚠️ UNMEASURED ASSUMPTION (FUAM-3841): Apple does not document SensorKit's on-device
    /// retention period; 7 days is the value this SDK has historically assumed, NOT a
    /// measured fact. If device QA shows the OS retains more (or less), tune this single
    /// constant — window building and backfill telemetry all follow from it.
    /// The backfill lower bound is `max(enrollmentDate, now - retentionFloor)`.
    private let retentionFloor: TimeInterval = 7 * 24 * 60 * 60

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
    // (review fix #5 — keying on window.start never fired when the bound was
    // now − retentionFloor, which shifts every cycle). Resets on relaunch; persist it in
    // storage if poison windows turn out to survive app restarts.
    private var windowFetchFailures: [SRSensor: Int] = [:]
    // Once-per-launch guard so the "empty_plan" telemetry (review fix #6) doesn't fire on
    // every 15-minute sync cycle while a fresh enrollment waits out the 24h embargo.
    private var emptyPlanReported: Set<SRSensor> = []
    private let syncLock = NSLock()
    private var hasStarted = false

    // MARK: - Init

    init(withSensors sensors: [SRSensor],
         storage: SensorSampleUploadManagerStorage & SensorSampleUploaderStorage,
         reachability: SensorSampleUploadManagerReachability,
         analytics: AnalyticsService,
         mappers: [SRSensor: SensorSampleMapper]) {
            precondition(!sensors.isEmpty, "Sensors must not be empty")
            self.sensors = sensors
            self.storage = storage
            self.reachability = reachability
            self.analytics = analytics
            self.mappers = mappers
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
    
    /// Report-like sensors are typically day-aggregated; prefer day-aligned windows when bootstrapping.
    private let dayAggregatedSensors: Set<SRSensor> = [
        .deviceUsageReport, .phoneUsageReport, .messagesUsageReport, .keyboardMetrics
    ]
    
    /// The windows to fetch for a sensor, plus the effective lower bound and what
    /// determined it ("cursor", "enrollment" or "retention_floor") — used for telemetry.
    struct WindowPlan {
        let windows: [DateInterval]
        let lowerBound: Date
        let lowerBoundOrigin: String
    }

    private func buildWindowPlan(for sensor: SRSensor, now: Date) -> WindowPlan {
        return Self.buildWindowPlan(dayAggregated: dayAggregatedSensors.contains(sensor),
                                    now: now,
                                    enrollmentDate: clearanceDelegate?.enrollmentDate,
                                    cursor: storage.lastCursor(for: sensor),
                                    retentionFloor: retentionFloor,
                                    embargo: sensorkitEmbargo)
    }

    /// Build embargo-safe fetch windows from the backfill lower bound (FUAM-3841) up to now.
    /// Pure (internal for unit tests).
    // swiftlint:disable:next function_parameter_count
    static func buildWindowPlan(dayAggregated: Bool,
                                now: Date,
                                enrollmentDate: Date?,
                                cursor: Date?,
                                retentionFloor: TimeInterval,
                                embargo: TimeInterval,
                                calendar: Calendar = .current) -> WindowPlan {
        let cal = calendar

        // Upper bound: honour the 24h SensorKit embargo. Report-type sensors are
        // day-aggregated, so additionally align DOWN to a day boundary ≤ now − embargo
        // (review fix #11 — a mid-day upper bound made the cursor land mid-day and the next
        // cycle re-fetch the same partial day forever).
        let embargoCutoff = now.addingTimeInterval(-embargo)
        let safeTo = dayAggregated ? cal.startOfDay(for: embargoCutoff) : embargoCutoff

        // Lower bound: reach back to the enrollment date, but never beyond what the OS
        // plausibly still holds (see `retentionFloor` — an unmeasured assumption).
        let retentionCutoff = now.addingTimeInterval(-retentionFloor)
        let lowerBound: Date
        var origin: String
        if let enrollment = enrollmentDate, enrollment > retentionCutoff {
            lowerBound = enrollment
            origin = "enrollment"
        } else {
            lowerBound = retentionCutoff
            origin = "retention_floor"
        }

        // Resume from the cursor when it is ahead of the lower bound. A cursor left behind
        // by purge + re-consent (FUAM-3844 keeps it in place) reopens from the bound —
        // never from `now` — so the gap is re-fetched.
        var from = lowerBound
        if let cursor = cursor, cursor > lowerBound {
            from = cursor
            origin = "cursor"
        }

        guard from < safeTo else { return WindowPlan(windows: [], lowerBound: from, lowerBoundOrigin: origin) }

        var windows: [DateInterval] = []
        if dayAggregated {
            // Day-aligned windows: [startOfDay, nextStartOfDay). Day-align `from` but never
            // rewind below the enrollment/retention bound (review fix #2 — startOfDay(from)
            // alone opened the first window before enrollment).
            var dayStart = max(cal.startOfDay(for: from), lowerBound)
            while dayStart < safeTo {
                guard let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: dayStart)) else { break }
                windows.append(DateInterval(start: dayStart, end: min(next, safeTo)))
                dayStart = next
            }
        } else {
            // Continuous sensors: chunk in 24h absolute windows; oversized results are
            // further split by payload size when enqueued.
            let chunk: TimeInterval = 24 * 60 * 60
            var start = from
            while start < safeTo {
                let end = min(start.addingTimeInterval(chunk), safeTo)
                windows.append(DateInterval(start: start, end: end))
                start = end
            }
        }

        return WindowPlan(windows: windows, lowerBound: from, lowerBoundOrigin: origin)
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

        let plan = buildWindowPlan(for: sensor, now: now)
        guard let firstWindow = plan.windows.first else {
            // Review fix #6: an empty plan on a would-be backfill (e.g. enrolled today, or
            // days_in_study == 0 upstream) must still leave a telemetry trace — otherwise a
            // sensor that never opens a window is indistinguishable from one never asked.
            if plan.lowerBoundOrigin != "cursor", !emptyPlanReported.contains(sensor) {
                emptyPlanReported.insert(sensor)
                analytics.track(event: .sensorDataBackfillReach(sensor: sensor.shortSubsource,
                                                                reachedBack: ISO8601DateFormatter().string(from: plan.lowerBound),
                                                                boundedBy: "empty_plan"))
            }
            #if DEBUG
            print("SensorSampleUploadManager - No windows for \(sensor.rawValue) (already up to date or embargo)")
            #endif
            return
        }

        // FUAM-3841 observability: how far back the client actually reached for this sensor.
        // Emitted only when the plan opens a backfill (not a routine cursor resume), so the
        // study team can tell "the OS deleted it" from "the client never asked".
        if plan.lowerBoundOrigin != "cursor" {
            analytics.track(event: .sensorDataBackfillReach(sensor: sensor.shortSubsource,
                                                            reachedBack: ISO8601DateFormatter().string(from: firstWindow.start),
                                                            boundedBy: plan.lowerBoundOrigin))
        }
        #if DEBUG
        print("SensorSampleUploadManager - \(sensor.rawValue): \(plan.windows.count) window(s) "
              + "from \(firstWindow.start) (bounded by \(plan.lowerBoundOrigin))")
        #endif

        processWindow(at: 0, of: plan.windows, for: sensor, using: mapper)
    }

    /// Sequentially process each window to respect mapper's "no concurrent fetch" precondition.
    private func processWindow(at index: Int,
                               of windows: [DateInterval],
                               for sensor: SRSensor,
                               using mapper: SensorSampleMapper) {
        guard index < windows.count else { return } // all done

        let window = windows[index]
        mapper.fetchAndMap(from: window.start, to: window.end) { [weak self] result in
            // Mapper callbacks arrive on arbitrary threads: hop onto the serial work queue
            // before touching windowFetchFailures / retryWorkItems / storage (review fix #10).
            guard let self else { return }
            self.workQueue.async { [weak self] in
                guard let self else { return }
                self.handleWindowResult(result, window: window, at: index, of: windows, for: sensor, using: mapper)
            }
        }
    }

    /// Runs on `workQueue` only.
    // swiftlint:disable:next function_parameter_count
    private func handleWindowResult(_ result: Result<[[String: Any]], Error>,
                                    window: DateInterval,
                                    at index: Int,
                                    of windows: [DateInterval],
                                    for sensor: SRSensor,
                                    using mapper: SensorSampleMapper) {
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
            let attempts = (self.windowFetchFailures[sensor] ?? 0) + 1
            if attempts >= self.maxWindowFetchAttempts {
                self.windowFetchFailures[sensor] = nil
                #if DEBUG
                print("SensorSampleUploadManager - Giving up window [\(window.start) -> \(window.end)] "
                      + "for \(sensor.rawValue) after \(attempts) attempts")
                #endif
                // Review fix #9: a forfeited window is data loss — leave a telemetry trace,
                // not just a DEBUG print.
                self.analytics.track(event: .sensorDataBackfillReach(sensor: sensor.shortSubsource,
                                                                     reachedBack: ISO8601DateFormatter().string(from: window.end),
                                                                     boundedBy: "gave_up"))
                self.storage.setLastCursor(window.end, for: sensor)
                self.processWindow(at: index + 1, of: windows, for: sensor, using: mapper)
            } else {
                self.windowFetchFailures[sensor] = attempts
                // Stop the chain for this cycle; the next sync retries from the cursor.
                self.scheduleRetry(for: sensor, attempt: attempts)
            }

        case .success(let records):
            self.windowFetchFailures[sensor] = nil

            // FUAM-3841 hard consent gate: drop anything measured before the enrollment
            // date, regardless of what SensorKit returned for the requested window.
            let uploadable = Self.dropPreEnrollmentRecords(records,
                                                           enrollmentDate: self.clearanceDelegate?.enrollmentDate,
                                                           windowStart: window.start)

            if uploadable.isEmpty {
                // Advance cursor even if empty to avoid refetching the same day/chunk again.
                self.storage.setLastCursor(window.end, for: sensor)
                // Move to next window
                self.processWindow(at: index + 1, of: windows, for: sensor, using: mapper)
                return
            }

            // Enqueue in batches bounded by record count AND serialized payload size.
            self.enqueueRespectingPayloadLimit(uploadable, for: sensor)

            // === Cursor advancement policy ===
            // "At-least-once" (simple): advance now; queued batches will be retried until uploaded.
            self.storage.setLastCursor(window.end, for: sensor)

            self.drainQueue(for: sensor)

            // Next window
            self.processWindow(at: index + 1, of: windows, for: sensor, using: mapper)
        }
    }

    // MARK: - Enrollment gate & payload chunking (FUAM-3841)

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoPlainFormatter = ISO8601DateFormatter()

    private static func parseISO8601(_ string: String) -> Date? {
        return isoPlainFormatter.date(from: string) ?? isoFractionalFormatter.date(from: string)
    }

    /// Best-effort extraction of the measurement timestamp from a mapped record.
    /// Mappers use heterogeneous keys: "t" (continuous sensors), "start"/"start_ms"
    /// (reports/pedometer), "recorded_at" (batch record time) as last resort.
    static func measurementDate(of record: [String: Any]) -> Date? {
        if let startMs = record["start_ms"] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
        }
        for key in ["t", "start", "recorded_at"] {
            if let string = record[key] as? String, let date = Self.parseISO8601(string) {
                return date
            }
        }
        return nil
    }

    /// Hard client-side consent gate: never enqueue (hence never transmit) a record measured
    /// before the enrollment date, independently of any server-side validation.
    /// Records without a parseable measurement timestamp are kept ONLY when the whole fetch
    /// window is provably ≥ enrollment; when the window opens before enrollment (day-aligned
    /// report windows can), a day aggregate covering pre-consent hours would otherwise leak
    /// through its post-enrollment `recorded_at` fallback (review fix #2).
    static func dropPreEnrollmentRecords(_ records: [[String: Any]],
                                         enrollmentDate: Date?,
                                         windowStart: Date) -> [[String: Any]] {
        guard let enrollment = enrollmentDate else { return records }
        let windowFullyPostEnrollment = windowStart >= enrollment
        return records.filter { record in
            guard let measuredAt = Self.measurementDate(of: record) else { return windowFullyPostEnrollment }
            return measuredAt >= enrollment
        }
    }

    /// Enqueue records in batches that respect both the record-count cap and the server's
    /// 10 MB request limit (oversized batches are bisected until they serialize below
    /// `maxBatchBytes`).
    private func enqueueRespectingPayloadLimit(_ records: [[String: Any]], for sensor: SRSensor) {
        Self.splitRespectingPayloadLimit(records, maxBatchSize: maxBatchSize, maxBatchBytes: maxBatchBytes)
            .forEach { self.storage.enqueueBatch($0, for: sensor) }
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
    private func drainQueue(for sensor: SRSensor, attempt: Int = 1) {
        guard reachability.isReachable else { return }
        // If there is nothing to upload, do not require a delegate
        if storage.pendingBatchCount(for: sensor) == 0 { return }

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

                net.uploadSensorBatch(sensor: sensor, payload: batch)
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
                            // Re-enqueue and schedule retry with backoff
                            self.storage.enqueueBatch(batch, for: sensor)
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
