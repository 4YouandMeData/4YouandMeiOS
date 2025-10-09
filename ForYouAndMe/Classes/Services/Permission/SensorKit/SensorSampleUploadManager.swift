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
    private let retentionDays: Int = 7                          // 7 calendar days

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
    private var retryWorkItems: [SRSensor: DispatchWorkItem] = [:]
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
            fetchWindow(for: sensor, to: now)
        }

        // Try to drain queues
        for sensor in sensors {
            drainQueue(for: sensor, baseDate: now)
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
    
    /// Build embargo and day-aligned windows for the last week up to 'yesterday'.
    private func buildWindows(for sensor: SRSensor, now: Date) -> [DateInterval] {
        let cal = Calendar.current
        let embargo: TimeInterval = 24 * 60 * 60

        // Upper bound you are allowed to read: not beyond yesterday nor within the last 24h.
        let startOfToday = cal.startOfDay(for: now)
        let embargoCutoff = now.addingTimeInterval(-embargo)
        let safeTo = min(startOfToday, embargoCutoff) // "yesterday" end, embargo-safe

        // Nothing readable yet
        guard let weekStartCandidate = cal.date(byAdding: .day, value: -7, to: startOfToday),
              weekStartCandidate < safeTo else {
            return []
        }

        // Start from last cursor if present, otherwise from 7 days ago
        let cursor = storage.lastCursor(for: sensor) ?? weekStartCandidate
        var from = min(cursor, weekStartCandidate)

        // Clamp 'from' to at most safeTo (nothing to do if already beyond)
        guard from < safeTo else { return [] }

        var windows: [DateInterval] = []

        if dayAggregatedSensors.contains(sensor) {
            // Day-aligned windows: [startOfDay, nextStartOfDay)
            // Start from startOfDay(from) to be robust if cursor is mid-day.
            var dayStart = cal.startOfDay(for: from)
            while dayStart < safeTo {
                guard let next = cal.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let dayEnd = min(next, safeTo)
                windows.append(DateInterval(start: dayStart, end: dayEnd))
                dayStart = next
            }
        } else {
            // Continuous sensors: chunk in 24h absolute windows (you can pick smaller, e.g., 6h)
            let chunk: TimeInterval = 24 * 60 * 60
            var start = from
            while start < safeTo {
                let end = min(start.addingTimeInterval(chunk), safeTo)
                windows.append(DateInterval(start: start, end: end))
                start = end
            }
        }

        return windows
    }
    
    private func fetchLastWeekUpToYesterday(for sensor: SRSensor, now: Date) {
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

        // Build windows for last week up to yesterday (embargo-safe)
        let windows = buildWindows(for: sensor, now: now)
        guard !windows.isEmpty else {
            #if DEBUG
            print("SensorSampleUploadManager - No windows for \(sensor.rawValue) (already up to date or embargo)")
            #endif
            return
        }

        processWindow(at: 0, of: windows, for: sensor, using: mapper)
    }

    /// Sequentially process each window to respect mapper's "no concurrent fetch" precondition.
    private func processWindow(at index: Int,
                               of windows: [DateInterval],
                               for sensor: SRSensor,
                               using mapper: SensorSampleMapper) {
        guard index < windows.count else { return } // all done

        let w = windows[index]
        mapper.fetchAndMap(from: w.start, to: w.end) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                // Do not advance cursor; schedule a retry and stop the chain.
                #if DEBUG
                print("SensorSampleUploadManager - Fetch failed \(sensor.rawValue) [\(w.start) -> \(w.end)]: \(error)")
                #endif
                self.scheduleRetry(for: sensor, attempt: 1)

            case .success(let records):
                if records.isEmpty {
                    // Advance cursor even if empty to avoid refetching the same day/chunk again.
                    self.storage.setLastCursor(w.end, for: sensor)
                    // Move to next window
                    self.processWindow(at: index + 1, of: windows, for: sensor, using: mapper)
                    return
                }

                // Enqueue in small batches
                var i = 0
                while i < records.count {
                    let j = min(i + self.maxBatchSize, records.count)
                    self.storage.enqueueBatch(Array(records[i..<j]), for: sensor)
                    i = j
                }

                // === Cursor advancement policy ===
                // "At-least-once" (simple): advance now; queued batches will be retried until uploaded.
                self.storage.setLastCursor(w.end, for: sensor)

                // If you prefer "exactly-once after upload success", move setLastCursor(w.end, ...) *after* a successful drain.
                self.drainQueue(for: sensor, baseDate: w.end)

                // Next window
                self.processWindow(at: index + 1, of: windows, for: sensor, using: mapper)
            }
        }
    }



    private func fetchWindow(for sensor: SRSensor, to now: Date) {
        
        self.fetchLastWeekUpToYesterday(for: sensor, now: Date())
        return
        // Authorization check
        guard isAuthorized(sensor) else {
            #if DEBUG
            print("SensorSampleUploadManager - Skip fetch \(sensor.rawValue): status=\(statusString(sensor))")
            #endif
            // Do NOT advance cursor here.
            return
        }

        // Resolve mapper
        guard let mapper = mappers[sensor] else {
            #if DEBUG
            print("SensorSampleUploadManager - Missing mapper for \(sensor.rawValue)")
            #endif
            return
        }

        let cal = Calendar.current

        // Embargo: SensorKit withholds the last 24h (absolute duration).
        // Do NOT read beyond this point.
        let embargoCutoff = now.addingTimeInterval(-sensorkitEmbargo)

        // Decide the "to" bound:
        //    - For day-aggregated reports, never go past startOfToday to avoid partial-day windows.
        //    - Still honor the 24h embargo by taking the minimum.
        let startOfToday = cal.startOfDay(for: now)
        let safeTo: Date = dayAggregatedSensors.contains(sensor)
            ? min(startOfToday, embargoCutoff)   // day-aligned but still ≤ now-24h
            : embargoCutoff                      // continuous sensors: last 24h absolute

        // Decide the "from" bound:
        //    - If we have a cursor, continue from there.
        //    - If no cursor:
        //        * day-aggregated: start from startOfYesterday (calendar-safe, DST-aware)
        //        * others: use the last 24h absolute (safeTo - 24h)
        var from: Date
        if let cursor = storage.lastCursor(for: sensor) {
            from = cursor
        } else {
            if dayAggregatedSensors.contains(sensor) {
                guard let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday) else {
                    // Fallback: if calendar fails, read nothing this round
                    return
                }
                from = startOfYesterday
            } else {
                from = safeTo.addingTimeInterval(-sensorkitEmbargo) // exact 24h span
            }
        }

        // Clamp to retention window (~7 calendar days before safeTo).
        if let oldestAllowed = cal.date(byAdding: .day, value: -retentionDays, to: safeTo), from < oldestAllowed {
            from = oldestAllowed
        }

        // Final sanity check
        guard from < safeTo else {
            #if DEBUG
            print("SensorSampleUploadManager - Empty/invalid window for \(sensor.rawValue). from=\(from) to=\(safeTo)")
            #endif
            return
        }

        // Perform fetch on [from, safeTo)
        mapper.fetchAndMap(from: from, to: safeTo) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                // Do not advance cursor; schedule a retry.
                #if DEBUG
                print("SensorSampleUploadManager - Fetch failed for \(sensor.rawValue): \(error)")
                print("SensorSampleUploadManager - Window was from=\(from) to=\(safeTo)")
                #endif
                self.scheduleRetry(for: sensor, attempt: 1)

            case .success(let records):
                if records.isEmpty {
                    // Even if empty, advance to safeTo to avoid refetching the same embargo-safe range.
                    self.storage.setLastCursor(safeTo, for: sensor)
                    return
                }

                // Enqueue in small batches for resilience
                var i = 0
                while i < records.count {
                    let j = min(i + self.maxBatchSize, records.count)
                    self.storage.enqueueBatch(Array(records[i..<j]), for: sensor)
                    i = j
                }

                // Advance cursor to what we *actually* read.
                // If you prefer exactly-once semantics post-upload-success, move this into `drainQueue` upon success.
                self.storage.setLastCursor(safeTo, for: sensor)

                // Try immediate upload
                self.drainQueue(for: sensor, baseDate: safeTo)
            }
        }
    }

    private func drainQueue(for sensor: SRSensor, baseDate: Date, attempt: Int = 1) {
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
                    // Queue drained: advance cursor
                    self.storage.setLastCursor(baseDate, for: sensor)
                    return
                }

                net.uploadSensorBatch(sensor: sensor, payload: batch)
                    .subscribe(
                        onSuccess: { [weak self] in
                            guard let self = self else { return }
                            // If more batches remain, keep going
                            if self.storage.pendingBatchCount(for: sensor) > 0 {
                                uploadNextBatch()
                            } else {
                                // Advance cursor only after draining all
                                self.storage.setLastCursor(baseDate, for: sensor)
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
        // Cancel previous retry if any
        retryWorkItems[sensor]?.cancel()

        let delay = min(retryMaxDelay, retryBaseDelay * pow(2.0, Double(max(0, attempt - 1))))
        let work = DispatchWorkItem { [weak self] in
            self?.drainQueue(for: sensor, baseDate: Date(), attempt: attempt)
        }
        retryWorkItems[sensor] = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: work)
    }
    
    private func purgeAllData(reason: String) {
        #if DEBUG
        print("SensorSampleUploadManager - Purging pending data (\(reason))")
        #endif

        // Stop pending retries
        retryWorkItems.values.forEach { $0.cancel() }
        retryWorkItems.removeAll()

        let now = Date()
        // Drop ALL queued batches and move cursor to 'now'
        for sensor in sensors {
            // Dequeue until the queue is empty
            while let _ = storage.dequeueNextBatch(for: sensor) { /* drop */ }
            // Move the cursor to 'now' so we don't refetch pre-login data
            storage.setLastCursor(now, for: sensor)
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
