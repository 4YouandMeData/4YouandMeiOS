//
//  SensorSampleUploadManagerStorage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit

/// Storage abstraction for SensorKit batching pipeline:
/// - Keeps per-sensor, per-device upload cursor (last successfully uploaded upper bound).
/// - Persists pending batches (FIFO) until successfully uploaded.
public protocol SensorSampleUploadManagerStorage: AnyObject {
    // Cursor (per sensor AND per device kind)

    /// `deviceKey` is `SensorDevice.key` — `"iphone"` for the device the app runs on, `"watch"`
    /// for a paired Apple Watch (FUAM-3945). Each kind walks its own plan at its own pace, so
    /// a Watch that syncs days late can never drag the iPhone cursor backwards or forwards.
    func lastCursor(for sensor: SRSensor, deviceKey: String) -> Date?
    func setLastCursor(_ date: Date, for sensor: SRSensor, deviceKey: String)

    // Queue (per sensor, device-mixed) of batches (each batch = array of JSON-ready
    // dictionaries). The device does NOT join the queue key: records are tagged individually
    // (`device_kind`) and a batch already carries the window it needs for the drain-time gate.

    /// `windowStart` is the start of the fetch window the records came from. It is persisted
    /// WITH the batch because the consent gate needs it again at drain time: a record whose
    /// measurement time cannot be read is kept only when its window vouches for it, and standing
    /// `.distantPast` in for the real window destroyed exactly those records, permanently
    /// (FUAM-3945 review round 3, I1).
    func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor)

    /// The head of the queue with the window it was fetched from, or `nil` when the queue is
    /// empty. Batches persisted by a build older than FUAM-3945 carry no window start and are
    /// purged on load rather than shipped under a guessed one.
    func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)?

    func pendingBatchCount(for sensor: SRSensor) -> Int
}

/// Marker protocol kept for symmetry with Health side (if you have a similar split there).
public protocol SensorSampleUploaderStorage: AnyObject {}

/// Simple UserDefaults-backed storage to get you running quickly.
/// For production-critical durability, prefer CoreData/SQLite.
public final class DefaultsSensorStorage: SensorSampleUploadManagerStorage, SensorSampleUploaderStorage {

    private let cursorKeyPrefix = "sensorkit.cursor."
    private let queueKeyPrefix  = "sensorkit.queue."

    private let syncQueue = DispatchQueue(label: "sensorkit.storage.sync", qos: .utility)

    public init() {}

    // MARK: - Cursor

    public func lastCursor(for sensor: SRSensor, deviceKey: String) -> Date? {
        return UserDefaults.standard.object(forKey: self.cursorKey(for: sensor, deviceKey: deviceKey)) as? Date
    }

    public func setLastCursor(_ date: Date, for sensor: SRSensor, deviceKey: String) {
        UserDefaults.standard.set(date, forKey: self.cursorKey(for: sensor, deviceKey: deviceKey))
    }

    /// The iPhone keeps the LEGACY, unsuffixed key; every other device kind is suffixed. That is
    /// the whole FUAM-3945 migration: no migration code, and rolling back to an older build is
    /// automatically safe — it reads exactly the key it always wrote, and the watch keys are
    /// ignored orphans.
    private func cursorKey(for sensor: SRSensor, deviceKey: String) -> String {
        let base = self.cursorKeyPrefix + sensor.rawValue
        return deviceKey == SensorDevice.iphoneKey ? base : base + "." + deviceKey
    }

    // MARK: - Queue

    public func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) {
        syncQueue.sync {
            var queue = loadQueue(for: sensor)
            queue.append(QueuedBatch(records: batch, windowStart: windowStart))
            saveQueue(queue, for: sensor)
        }
    }

    public func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)? {
        return syncQueue.sync {
            var queue = loadQueue(for: sensor)
            guard !queue.isEmpty else { return nil }
            let head = queue.removeFirst()
            saveQueue(queue, for: sensor)
            return (head.records, head.windowStart)
        }
    }

    public func pendingBatchCount(for sensor: SRSensor) -> Int {
        return syncQueue.sync { loadQueue(for: sensor).count }
    }

    // MARK: - Helpers

    private struct QueuedBatch {
        let records: [[String: Any]]
        let windowStart: Date
    }

    private static let recordsKey = "records"
    private static let windowStartKey = "window_start"

    /// Loads the queue, DROPPING any entry not in the FUAM-3945 shape. The pre-FUAM-3945 format
    /// was a bare array of records with no window start; such a batch cannot be consent-filtered
    /// (its undecidable records would have to be dropped anyway) and predates this policy, so it
    /// is purged once, on the first load after the upgrade.
    private func loadQueue(for sensor: SRSensor) -> [QueuedBatch] {
        let key = queueKeyPrefix + sensor.rawValue
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        let queue: [QueuedBatch] = entries.compactMap { entry in
            guard let dictionary = entry as? [String: Any],
                  let records = dictionary[Self.recordsKey] as? [[String: Any]],
                  let windowStart = dictionary[Self.windowStartKey] as? Double else { return nil }
            return QueuedBatch(records: records, windowStart: Date(timeIntervalSince1970: windowStart))
        }
        if queue.count != entries.count {
            // Rewrite the blob so the purged legacy records do not stay at rest on the device.
            saveQueue(queue, for: sensor)
        }
        return queue
    }

    private func saveQueue(_ queue: [QueuedBatch], for sensor: SRSensor) {
        let key = queueKeyPrefix + sensor.rawValue
        let entries: [[String: Any]] = queue.map {
            [Self.recordsKey: $0.records, Self.windowStartKey: $0.windowStart.timeIntervalSince1970]
        }
        if let data = try? JSONSerialization.data(withJSONObject: entries, options: []) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
