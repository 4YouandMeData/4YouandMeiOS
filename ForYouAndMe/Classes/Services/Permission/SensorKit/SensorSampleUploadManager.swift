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
    private let minSyncInterval: TimeInterval = 15 * 60 // 15 minutes

    /// Exponential backoff boundaries for retry.
    private let retryBaseDelay: TimeInterval = 30
    private let retryMaxDelay: TimeInterval = 15 * 60

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

    private func fetchWindow(for sensor: SRSensor, to now: Date) {
        guard isAuthorized(sensor) else {
            #if DEBUG
            print("SensorSampleUploadManager - Skip fetch \(sensor.rawValue): status=\(statusString(sensor))")
            #endif
            // Important: do NOT advance cursor and do NOT schedule retry here.
            // When/if the user grants permission, a future triggerSync() will pick it up.
            return
        }
        
        guard let mapper = mappers[sensor] else {
            #if DEBUG
            print("SensorSampleUploadManager - Missing mapper for \(sensor.rawValue)")
            #endif
            return
        }

        let from = storage.lastCursor(for: sensor) ?? Date(timeIntervalSinceNow: -24 * 60 * 60) // last 24h

        // Sanity check on window
        guard from < now.addingTimeInterval(-1) else { return }

        mapper.fetchAndMap(from: from, to: now) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                // Do not advance cursor; schedule a retry
                #if DEBUG
                print("SensorSampleUploadManager - Fetch failed for \(sensor.rawValue): \(error)")
                #endif
                self.scheduleRetry(for: sensor, attempt: 1)

            case .success(let records):
                guard !records.isEmpty else {
                    // No data in window: still advance cursor to now to avoid refetching same empty range
                    self.storage.setLastCursor(now, for: sensor)
                    return
                }

                // Split into batches to keep requests small and resilient
                var id = 0
                while id < records.count {
                    let end = min(id + self.maxBatchSize, records.count)
                    let batch = Array(records[id..<end])
                    self.storage.enqueueBatch(batch, for: sensor)
                    id = end
                }

                // Try to upload immediately
                self.drainQueue(for: sensor, baseDate: now)
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
