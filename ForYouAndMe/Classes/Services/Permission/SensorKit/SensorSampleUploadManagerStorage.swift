//
//  SensorSampleUploadManagerStorage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit

/// One upload-ledger entry (FUAM-3945, D4): the fingerprint key it lives under identifies the
/// record; the entry carries what pruning and drift telemetry need.
public struct SensorLedgerEntry: Codable, Equatable {
    /// UTC day of the window the record was first enqueued from — the pruning key.
    public let day: Date
    /// The record's measurement period, when one is derivable (the three usage reports whose
    /// `duration_s` IS a span). Only used to measure S7 boundary drift (`sensor_near_duplicate`).
    public let periodStart: Date?
    public let periodEnd: Date?

    public init(day: Date, periodStart: Date? = nil, periodEnd: Date? = nil) {
        self.day = day
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }
}

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
    ///
    /// Returns `false` when the batch could not be PERSISTED (AC4): the caller must then leave
    /// the cursor alone, because "enqueued" is what makes a window durably handled.
    @discardableResult
    func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> Bool

    /// The head of the queue with the window it was fetched from, or `nil` when the queue is
    /// empty. Batches persisted by a build older than FUAM-3945 carry no window start and are
    /// purged on load rather than shipped under a guessed one.
    func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)?

    func pendingBatchCount(for sensor: SRSensor) -> Int

    // Upload ledger (FUAM-3945, D4): per sensor+device fingerprints of every record already
    // enqueued, so a re-fetch (widened span, rescan tail, travel overlap) never re-uploads.

    func ledger(for sensor: SRSensor, deviceKey: String) -> [String: SensorLedgerEntry]
    func setLedger(_ ledger: [String: SensorLedgerEntry], for sensor: SRSensor, deviceKey: String)
    /// Drops every device's ledger for `sensor` — called from `purgeAllData` together with the
    /// queue purge, so a purged batch can be re-collected after a re-consent.
    func purgeLedger(for sensor: SRSensor)

    // Rescan gate (FUAM-3945, D3): the last UTC day a rescan tail was planned for.

    func lastRescanDay(for sensor: SRSensor, deviceKey: String) -> Date?
    func setLastRescanDay(_ day: Date, for sensor: SRSensor, deviceKey: String)

    // Measured OS retention (FUAM-3945, AC1): the deepest window that ever returned data.

    func deepestProductiveWindowStart(for sensor: SRSensor, deviceKey: String) -> Date?
    func setDeepestProductiveWindowStart(_ date: Date, for sensor: SRSensor, deviceKey: String)
}

/// Marker protocol kept for symmetry with Health side (if you have a similar split there).
public protocol SensorSampleUploaderStorage: AnyObject {}

/// Simple UserDefaults-backed storage to get you running quickly.
/// For production-critical durability, prefer CoreData/SQLite.
public final class DefaultsSensorStorage: SensorSampleUploadManagerStorage, SensorSampleUploaderStorage {

    private let cursorKeyPrefix = "sensorkit.cursor."
    private let queueKeyPrefix  = "sensorkit.queue."
    private let ledgerKeyPrefix = "sensorkit.ledger."
    private let rescanDayKeyPrefix = "sensorkit.rescanday."
    private let deepestWindowKeyPrefix = "sensorkit.deepestwindow."

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

    // MARK: - Ledger (FUAM-3945, D4)

    /// One blob per sensor, keyed by device inside, so `purgeLedger` is a single key removal and
    /// never has to guess which device kinds exist.
    public func ledger(for sensor: SRSensor, deviceKey: String) -> [String: SensorLedgerEntry] {
        return syncQueue.sync {
            return self.loadLedgers(for: sensor)[deviceKey] ?? [:]
        }
    }

    public func setLedger(_ ledger: [String: SensorLedgerEntry], for sensor: SRSensor, deviceKey: String) {
        syncQueue.sync {
            var ledgers = self.loadLedgers(for: sensor)
            ledgers[deviceKey] = ledger
            if let data = try? JSONEncoder().encode(ledgers) {
                UserDefaults.standard.set(data, forKey: self.ledgerKeyPrefix + sensor.rawValue)
            }
        }
    }

    public func purgeLedger(for sensor: SRSensor) {
        syncQueue.sync {
            UserDefaults.standard.removeObject(forKey: self.ledgerKeyPrefix + sensor.rawValue)
        }
    }

    private func loadLedgers(for sensor: SRSensor) -> [String: [String: SensorLedgerEntry]] {
        guard let data = UserDefaults.standard.data(forKey: self.ledgerKeyPrefix + sensor.rawValue),
              let ledgers = try? JSONDecoder().decode([String: [String: SensorLedgerEntry]].self, from: data) else {
            return [:]
        }
        return ledgers
    }

    // MARK: - Rescan gate (FUAM-3945, D3) & measured retention (AC1)

    public func lastRescanDay(for sensor: SRSensor, deviceKey: String) -> Date? {
        return UserDefaults.standard.object(forKey: self.suffixedKey(self.rescanDayKeyPrefix,
                                                                     sensor: sensor,
                                                                     deviceKey: deviceKey)) as? Date
    }

    public func setLastRescanDay(_ day: Date, for sensor: SRSensor, deviceKey: String) {
        UserDefaults.standard.set(day, forKey: self.suffixedKey(self.rescanDayKeyPrefix,
                                                                sensor: sensor,
                                                                deviceKey: deviceKey))
    }

    public func deepestProductiveWindowStart(for sensor: SRSensor, deviceKey: String) -> Date? {
        return UserDefaults.standard.object(forKey: self.suffixedKey(self.deepestWindowKeyPrefix,
                                                                     sensor: sensor,
                                                                     deviceKey: deviceKey)) as? Date
    }

    public func setDeepestProductiveWindowStart(_ date: Date, for sensor: SRSensor, deviceKey: String) {
        UserDefaults.standard.set(date, forKey: self.suffixedKey(self.deepestWindowKeyPrefix,
                                                                 sensor: sensor,
                                                                 deviceKey: deviceKey))
    }

    /// Unlike the cursor there is no legacy key to preserve: every device kind is suffixed.
    private func suffixedKey(_ prefix: String, sensor: SRSensor, deviceKey: String) -> String {
        return prefix + sensor.rawValue + "." + deviceKey
    }

    // MARK: - Queue

    @discardableResult
    public func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> Bool {
        return syncQueue.sync {
            var queue = loadQueue(for: sensor)
            queue.append(QueuedBatch(records: batch, windowStart: windowStart))
            return saveQueue(queue, for: sensor)
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

    /// `false` when the queue could not be serialized (AC4): the caller treats the enqueue as
    /// not having happened and leaves the cursor alone.
    @discardableResult
    private func saveQueue(_ queue: [QueuedBatch], for sensor: SRSensor) -> Bool {
        let key = queueKeyPrefix + sensor.rawValue
        let entries: [[String: Any]] = queue.map {
            [Self.recordsKey: $0.records, Self.windowStartKey: $0.windowStart.timeIntervalSince1970]
        }
        guard JSONSerialization.isValidJSONObject(entries),
              let data = try? JSONSerialization.data(withJSONObject: entries, options: []) else {
            return false
        }
        UserDefaults.standard.set(data, forKey: key)
        return true
    }
}
