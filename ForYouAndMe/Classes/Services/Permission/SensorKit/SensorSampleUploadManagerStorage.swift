//
//  SensorSampleUploadManagerStorage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit

/// Storage abstraction for SensorKit batching pipeline:
/// - Keeps per-sensor upload cursor (last successfully uploaded upper bound).
/// - Persists pending batches (FIFO) until successfully uploaded.
public protocol SensorSampleUploadManagerStorage: AnyObject {
    // Cursor (per sensor)
    func lastCursor(for sensor: SRSensor) -> Date?
    func setLastCursor(_ date: Date, for sensor: SRSensor)

    // Queue (per sensor) of batches (each batch = array of JSON-ready dictionaries)
    func enqueueBatch(_ batch: [[String: Any]], for sensor: SRSensor)
    func dequeueNextBatch(for sensor: SRSensor) -> [[String: Any]]?
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

    public func lastCursor(for sensor: SRSensor) -> Date? {
        let key = cursorKeyPrefix + sensor.rawValue
        return UserDefaults.standard.object(forKey: key) as? Date
    }

    public func setLastCursor(_ date: Date, for sensor: SRSensor) {
        let key = cursorKeyPrefix + sensor.rawValue
        UserDefaults.standard.set(date, forKey: key)
    }

    // MARK: - Queue

    public func enqueueBatch(_ batch: [[String: Any]], for sensor: SRSensor) {
        syncQueue.sync {
            var queue = loadQueue(for: sensor)
            queue.append(batch)
            saveQueue(queue, for: sensor)
        }
    }

    public func dequeueNextBatch(for sensor: SRSensor) -> [[String: Any]]? {
        return syncQueue.sync {
            var queue = loadQueue(for: sensor)
            guard !queue.isEmpty else { return nil }
            let head = queue.removeFirst()
            saveQueue(queue, for: sensor)
            return head
        }
    }

    public func pendingBatchCount(for sensor: SRSensor) -> Int {
        return syncQueue.sync { loadQueue(for: sensor).count }
    }

    // MARK: - Helpers

    private func loadQueue(for sensor: SRSensor) -> [[[String: Any]]] {
        let key = queueKeyPrefix + sensor.rawValue
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[[String: Any]]] else { return [] }
        return arr
    }

    private func saveQueue(_ queueArr: [[[String: Any]]], for sensor: SRSensor) {
        let key = queueKeyPrefix + sensor.rawValue
        if let data = try? JSONSerialization.data(withJSONObject: queueArr, options: []) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
