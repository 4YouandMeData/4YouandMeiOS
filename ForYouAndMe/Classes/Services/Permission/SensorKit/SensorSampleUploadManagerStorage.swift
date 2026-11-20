//
//  SensorSampleUploadManagerStorage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import CryptoKit
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

/// One persisted upload batch (FUAM-3945 round 6, V2). `id` is assigned at enqueue and stable
/// for as long as the batch stays queued: the drain peeks a batch, uploads it, and removes or
/// requeues it by `id`, so a batch leaves the queue only once its fate is decided.
public struct SensorQueuedBatch {
    public let id: String
    public let records: [[String: Any]]
    public let windowStart: Date
    /// FUAM-4516: the backend user id of the participant the batch was collected for, `nil` when
    /// none was recorded.
    public let owner: String?

    public init(id: String, records: [[String: Any]], windowStart: Date, owner: String? = nil) {
        self.id = id
        self.records = records
        self.windowStart = windowStart
        self.owner = owner
    }
}

/// How an enqueue ended (FUAM-4517, plan R2 PR-1). The two failures are handled differently: a
/// write failure is retried by the next sync and never advances a cursor; content that cannot be
/// serialized can never be written, so its window keeps the 3-attempt give-up (FUAM-3841).
public enum SensorEnqueueOutcome: Equatable {
    /// Durably written. `id` is the new batch's id, or `nil` from a storage that cannot report it
    /// (such a batch cannot be rolled back).
    case enqueued(id: String?)
    /// A file-system error: disk full, a protection or permission error, an I/O error.
    case writeFailed
    /// `JSONSerialization` rejected the content.
    case unserializable
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

    /// `enqueueBatch` with the outcome spelled out and the new batch's id (FUAM-4517): what the
    /// pipeline uses, so it can tell a write failure from unserializable content and roll back the
    /// batches a window already wrote. The default derives it from `enqueueBatch`: content that does
    /// not serialize is `.unserializable`, any other `false` is `.writeFailed`, the id is unknown.
    func enqueueBatchReportingOutcome(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> SensorEnqueueOutcome

    /// The head of the queue with the window it was fetched from, REMOVED from the queue, or
    /// `nil` when the queue is empty. Only for dropping batches: an upload
    /// must `peekNextBatch` and remove on success instead, or a process kill mid-request loses
    /// the batch. Batches persisted by a build older than FUAM-3945 carry no window start and
    /// are purged on load rather than shipped under a guessed one.
    func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)?

    /// FUAM-3945 round 6 (V2): the first queued batch whose `id` is not in `excluding`, LEFT in
    /// the persisted queue, or `nil`. The drain uploads it and only then removes it
    /// (`removeBatch`), so a kill during the request leaves it queued for the next drain;
    /// `excluding` holds the batches another drain chain has in flight, so no batch is ever
    /// uploaded twice concurrently. `id` is stable for the life of the queued batch.
    func peekNextBatch(for sensor: SRSensor, excluding ids: Set<String>) -> SensorQueuedBatch?

    /// Removes the batch with `id` wherever it sits; a no-op when it is gone (purged meanwhile).
    func removeBatch(id: String, for sensor: SRSensor)

    /// Atomically replaces the batch with `id` by `records` (same window start) at the TAIL of
    /// the queue: one persisted write, so a kill can neither lose nor duplicate it. A no-op
    /// returning `true` when the batch is gone (a purge meant "drop"); `false` only when the
    /// queue could not be persisted.
    @discardableResult
    func requeueBatch(id: String, records: [[String: Any]], for sensor: SRSensor) -> Bool

    func pendingBatchCount(for sensor: SRSensor) -> Int

    // Upload ledger (FUAM-3945, D4): per sensor+device fingerprints of every record already
    // enqueued, so a re-fetch (widened span, rescan tail, travel overlap) never re-uploads.

    func ledger(for sensor: SRSensor, deviceKey: String) -> [String: SensorLedgerEntry]
    func setLedger(_ ledger: [String: SensorLedgerEntry], for sensor: SRSensor, deviceKey: String)
    /// Drops every device's ledger for `sensor`. Not called by the pipeline since FUAM-4516
    /// (ownership replaced the purge: `adoptOwner` resets a previous participant's state).
    func purgeLedger(for sensor: SRSensor)

    // Rescan gate (FUAM-3945, D3): the last UTC day a rescan tail was planned for.

    func lastRescanDay(for sensor: SRSensor, deviceKey: String) -> Date?
    func setLastRescanDay(_ day: Date, for sensor: SRSensor, deviceKey: String)

    // Measured OS retention (FUAM-3945, AC1): the deepest window that ever returned data.

    func deepestProductiveWindowStart(for sensor: SRSensor, deviceKey: String) -> Date?
    func setDeepestProductiveWindowStart(_ date: Date, for sensor: SRSensor, deviceKey: String)

    // Ownership and set-aside items (FUAM-4516). Default implementations below keep any other
    // conformer compiling.

    /// Declares the logged-in participant (backend user id). Cursors, ledger, rescan gate and
    /// deepest window belong to one participant: when `owner` differs from the participant they
    /// were recorded for, they are reset, so a new participant starts clean; when none was
    /// recorded (state written by 0.101.17 or older), `owner` adopts them. New batches are stamped
    /// with `owner`, and a queued batch stamped with a different participant is deleted at drain
    /// time instead of being uploaded.
    func adoptOwner(_ owner: String)

    /// Sets aside descriptions of records that cannot be encoded (FUAM-4516 owner rule 7): kept in
    /// the quarantine for 7 days, never uploaded. `false` when they could not be written: the
    /// caller then treats the window as not handled.
    func setAside(_ descriptions: [[String: Any]], reason: String, for sensor: SRSensor) -> Bool

    /// When the current participant took over from a different one (`adoptOwner`), `nil` when no
    /// hand-over happened on this install. Nothing measured before it is ever collected or
    /// uploaded for the current participant (final review P-1).
    func ownerSince() -> Date?
}

public extension SensorSampleUploadManagerStorage {

    func adoptOwner(_ owner: String) {}

    func enqueueBatchReportingOutcome(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> SensorEnqueueOutcome {
        // `isValidJSONObject` lets NaN through; only serializing tells.
        guard JSONSerialization.isValidJSONObject(batch),
              (try? JSONSerialization.data(withJSONObject: batch)) != nil else { return .unserializable }
        return self.enqueueBatch(batch, windowStart: windowStart, for: sensor) ? .enqueued(id: nil) : .writeFailed
    }

    func setAside(_ descriptions: [[String: Any]], reason: String, for sensor: SRSensor) -> Bool { return true }

    func ownerSince() -> Date? { return nil }
}

/// Marker protocol kept for symmetry with Health side (if you have a similar split there).
public protocol SensorSampleUploaderStorage: AnyObject {}

/// The SensorKit pipeline's persistent state. Cursors, the upload ledger, the rescan gate and the
/// deepest window are small values in `UserDefaults`. The upload QUEUE is one file per batch under
/// Application Support (FUAM-4516): every queue operation touches one batch, so memory per
/// operation no longer grows with the backlog. `sensorkit.queue.<sensor>` in `UserDefaults` is the
/// 0.101.16/17 queue, migrated once per sensor at its first queue access.
///
/// The class keeps its pre-FUAM-4516 name because it is public and existing specs use it.
public final class DefaultsSensorStorage: SensorSampleUploadManagerStorage, SensorSampleUploaderStorage {

    private let cursorKeyPrefix = "sensorkit.cursor."
    private let queueKeyPrefix  = "sensorkit.queue."
    private let ledgerKeyPrefix = "sensorkit.ledger."
    private let rescanDayKeyPrefix = "sensorkit.rescanday."
    private let deepestWindowKeyPrefix = "sensorkit.deepestwindow."

    /// Serialises every ledger and queue operation. Every call is `sync` on the caller's thread,
    /// so the queue's autorelease frequency never applies: each queue operation drains its own
    /// explicit `autoreleasepool` instead (FUAM-4516, plan R2 PR-16 item 4).
    private let syncQueue = DispatchQueue(label: "sensorkit.storage.sync", qos: .utility)

    // FUAM-4516 queue state. Everything below is touched on `syncQueue` only.
    private let queueRoot: URL
    private let analytics: AnalyticsService?
    private let fileManager = FileManager.default
    private var rootPrepared = false
    /// Sensors whose legacy queue is known to be fully migrated (or absent) in this process.
    private var migratedSensors: Set<String> = []
    /// Sensors whose migration already ran once in this process: a failed migration (write
    /// error) is retried at the next launch, never in a loop that re-parses a multi-MB blob.
    private var migrationAttempted: Set<String> = []
    /// Next batch sequence per sensor: the highest sequence on disk + 1 at first use, then kept
    /// in memory. Never derived from the clock, so a clock change cannot reorder the queue.
    private var nextSequence: [String: Int] = [:]
    /// Per sensor, the batch files in queue order (review B-5). Built from one directory listing
    /// at first use and kept in step by every queue operation, so a drain no longer lists and sorts
    /// the directory twice per batch (85 s of CPU for 2,000 files). The file system stays the
    /// source of truth: a file the index lists but the disk does not have makes the index rebuild
    /// from a fresh listing, and so does a removal of an id the index does not know.
    private var batchIndex: [String: [BatchFile]] = [:]
    /// Directory listings of sensor directories so far; read by the index spec only.
    private var directoryListings = 0
    /// Sensors whose unreadable batch file was already traced in this process: a read error is
    /// "retry later", traced once, not on every drain (owner rule 5).
    private var unreadableReported: Set<String> = []
    /// The participant the queue and the cursors belong to (`adoptOwner`), mirrored from
    /// `ownerKey`. `nil` until a session declared one.
    private var owner: String?
    /// Per sensor, batches whose removal failed (review A-5). Every removal follows an upload the
    /// server accepted or a decision to drop, so such a batch must never be peeked again in this
    /// process, or the drain would upload it in a loop; the unlink is retried at each queue
    /// access. In memory only: a relaunch uploads it once more, which the server drops by
    /// identity. FUAM-4517 owns the durable delete-on-200.
    private var pendingRemovals: [String: Set<String>] = [:]

    /// `<Application Support>/ForYouAndMe/SensorKitQueue/`. Backed up like `UserDefaults`, so a
    /// restored device gets the queue and the cursors together (plan §2.1, OQ12).
    static var defaultQueueDirectory: URL {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ForYouAndMe", isDirectory: true)
            .appendingPathComponent("SensorKitQueue", isDirectory: true)
    }

    public convenience init() {
        self.init(queueDirectory: Self.defaultQueueDirectory)
    }

    /// `queueDirectory` is injectable so specs run on a temp directory; `analytics` receives the
    /// queue telemetry (migration outcome, quarantined batches, dropped legacy entries).
    init(queueDirectory: URL, analytics: AnalyticsService? = nil) {
        self.queueRoot = queueDirectory
        self.analytics = analytics
    }

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

    // MARK: - Queue (FUAM-4516: one file per batch)
    //
    // `<queueRoot>/<SRSensor.rawValue>/<seq>_<id>.json`, `seq` a 12-digit per-sensor sequence. A file
    // holds exactly one entry of the 0.101.16/17 `UserDefaults` array: `{"id", "window_start",
    // "records"}`. Writes are atomic (temp file + rename), so a batch file exists complete or not at
    // all; removal is one unlink; moving a batch to the tail is one rename. Any other name in the
    // directory is ignored.

    @discardableResult
    public func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> Bool {
        if case .enqueued = self.enqueueBatchReportingOutcome(batch, windowStart: windowStart, for: sensor) { return true }
        return false
    }

    public func enqueueBatchReportingOutcome(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> SensorEnqueueOutcome {
        return self.syncQueue.sync {
            autoreleasepool {
                self.prepareRootIfNeeded()
                _ = self.ensureMigrated(sensor)
                self.retryPendingRemovals(sensor)
                return self.writeNewBatch(id: UUID().uuidString, records: batch, windowStart: windowStart, for: sensor)
            }
        }
    }

    public func peekNextBatch(for sensor: SRSensor, excluding ids: Set<String>) -> SensorQueuedBatch? {
        return self.syncQueue.sync {
            autoreleasepool {
                self.prepareRootIfNeeded()
                // Not migrated yet: report an EMPTY queue, so the drain can never upload (and
                // delete) a file that the still-pending migration would write again.
                guard self.ensureMigrated(sensor) else { return nil }
                self.retryPendingRemovals(sensor)
                let excluded = ids.union(self.pendingRemovals[sensor.rawValue] ?? [])
                var foreignDeleted = 0
                defer {
                    if foreignDeleted > 0 {
                        // One event per peek, the count only (batches).
                        self.analytics?.track(event: .sensorRecordDropped(sensor: sensor.shortSubsource,
                                                                          count: foreignDeleted,
                                                                          reason: "other_participant"))
                    }
                }
                var relisted = false
                while true {
                    guard let listed = self.indexedBatches(sensor) else { return nil }
                    var stale = false
                    for file in listed where !excluded.contains(file.id) {
                        switch self.readBatch(file) {
                        case .batch(let batch):
                            // Owner rule 4: a batch collected for another participant is never
                            // uploaded under this one; it is deleted (a positive fact recorded in
                            // the batch, not an inference). No recorded owner means this one's.
                            if let current = self.owner, let batchOwner = batch.owner, batchOwner != current {
                                if self.unlink(file, for: sensor) { foreignDeleted += 1 }
                                continue
                            }
                            return batch
                        case .missing:
                            stale = true
                        case .unreadable:
                            // Owner rule 5: a read error is not corruption. Leave everything in
                            // place and stop this sensor's drain; the next sync retries.
                            if self.unreadableReported.insert(sensor.rawValue).inserted {
                                self.analytics?.track(event: .sensorRecordDropped(sensor: sensor.shortSubsource,
                                                                                  count: 0,
                                                                                  reason: "batch_unreadable_retry"))
                            }
                            return nil
                        case .unparseable:
                            // Read successfully and invalid: set aside (7 days), the drain moves on.
                            self.quarantine(file, sensor: sensor, reason: "batch_unparseable")
                        }
                        if stale { break }
                    }
                    // Before answering "nothing to upload", or when the index listed a file the
                    // disk does not have, rebuild the index once from a fresh listing and look
                    // again: a file the index missed is never skipped, none is read twice. One
                    // listing per drained queue, not one per batch.
                    guard !relisted else { return nil }
                    relisted = true
                    self.batchIndex[sensor.rawValue] = nil
                }
            }
        }
    }

    public func removeBatch(id: String, for sensor: SRSensor) {
        self.syncQueue.sync {
            autoreleasepool {
                self.prepareRootIfNeeded()
                var file = self.indexedBatches(sensor)?.first(where: { $0.id == id })
                if file == nil {
                    // Unknown to the index: confirm on disk before concluding it is gone.
                    self.batchIndex[sensor.rawValue] = nil
                    file = self.indexedBatches(sensor)?.first(where: { $0.id == id })
                }
                guard let found = file else { return }
                guard !self.unlink(found, for: sensor) else { return }
                if self.pendingRemovals[sensor.rawValue, default: []].insert(id).inserted {
                    // `count` is one BATCH; nothing is lost, it is just not deleted yet.
                    self.analytics?.track(event: .sensorRecordDropped(sensor: sensor.shortSubsource,
                                                                      count: 1,
                                                                      reason: "batch_remove_failed"))
                }
            }
        }
    }

    /// A batch that is gone (a purge meant "drop") is NOT written back (plan R2 PR-6). Otherwise the
    /// filtered content overwrites the same path atomically, then one rename moves it to the tail:
    /// no step ever leaves two files with the same id.
    @discardableResult
    public func requeueBatch(id: String, records: [[String: Any]], for sensor: SRSensor) -> Bool {
        return self.syncQueue.sync {
            autoreleasepool {
                self.prepareRootIfNeeded()
                guard let listed = self.indexedBatches(sensor) else { return false }
                guard let file = listed.first(where: { $0.id == id }) else { return true }
                let read = self.readBatch(file)
                if case .missing = read {
                    // Gone from disk (purged meanwhile): nothing to write back.
                    self.batchIndex[sensor.rawValue] = nil
                    return true
                }
                guard case .batch(let current) = read else { return false }
                if !(current.records as NSArray).isEqual(to: records) {
                    var content: [String: Any] = [Self.idKey: id,
                                                  Self.windowStartKey: current.windowStart.timeIntervalSince1970,
                                                  Self.recordsKey: records]
                    content[Self.ownerContentKey] = current.owner
                    guard self.writeJSON(content, to: file.url) else { return false }
                }
                guard let sequence = self.takeSequence(for: sensor) else { return false }
                let tail = self.sensorDirectory(sensor).appendingPathComponent(Self.batchName(sequence: sequence, id: id))
                do {
                    try self.fileManager.moveItem(at: file.url, to: tail)
                } catch {
                    return false
                }
                self.batchIndex[sensor.rawValue]?.removeAll { $0.id == id }
                self.batchIndex[sensor.rawValue]?.append(BatchFile(sequence: sequence, id: id, url: tail))
                return true
            }
        }
    }

    public func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)? {
        guard let head = self.peekNextBatch(for: sensor, excluding: []) else { return nil }
        self.removeBatch(id: head.id, for: sensor)
        return (head.records, head.windowStart)
    }

    public func pendingBatchCount(for sensor: SRSensor) -> Int {
        return self.syncQueue.sync {
            self.prepareRootIfNeeded()
            guard self.ensureMigrated(sensor) else { return 0 }
            self.retryPendingRemovals(sensor)
            let pending = self.pendingRemovals[sensor.rawValue] ?? []
            return self.indexedBatches(sensor)?.filter { !pending.contains($0.id) }.count ?? 0
        }
    }

    // MARK: - Ownership and set-aside items (FUAM-4516 owner rules 4, 6, 7)

    public func adoptOwner(_ owner: String) {
        self.syncQueue.sync {
            let stored = UserDefaults.standard.string(forKey: Self.ownerKey)
            self.owner = owner
            guard stored != owner else { return }
            // Final review R-1: the owner (and the hand-over instant) first, the resets after. A lost
            // reset leaves the previous cursors behind the hand-over bound, which re-sends and
            // exposes nothing; a lost owner write after the resets would reset this participant
            // again at the next launch.
            UserDefaults.standard.set(owner, forKey: Self.ownerKey)
            if stored != nil {
                // Final review P-1: the device still holds the previous participant's SensorKit
                // history; nothing measured before this instant is collected or uploaded for the
                // new one. A first adoption (no previous owner) sets no hand-over bound.
                UserDefaults.standard.set(Date(), forKey: Self.ownerSinceKey)
                // A different participant: the cursors, ledger, rescan gate and deepest window
                // describe the previous one's data. Reset them so this one starts clean; the
                // previous one's queued batches are deleted, unsent, when the drain meets them.
                let prefixes = [self.cursorKeyPrefix, self.ledgerKeyPrefix, self.rescanDayKeyPrefix, self.deepestWindowKeyPrefix]
                for key in UserDefaults.standard.dictionaryRepresentation().keys where prefixes.contains(where: { key.hasPrefix($0) }) {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }

    public func ownerSince() -> Date? {
        return UserDefaults.standard.object(forKey: Self.ownerSinceKey) as? Date
    }

    public func setAside(_ descriptions: [[String: Any]], reason: String, for sensor: SRSensor) -> Bool {
        return self.syncQueue.sync {
            autoreleasepool {
                self.prepareRootIfNeeded()
                let name = Self.quarantineName(sensor: sensor, item: "set-aside-\(UUID().uuidString)", reason: reason)
                guard self.ensureDirectory(self.quarantineDirectory),
                      self.writeJSON(descriptions, to: self.quarantineDirectory.appendingPathComponent(name)) else { return false }
                self.analytics?.track(event: .sensorRecordDropped(sensor: sensor.shortSubsource,
                                                                  count: descriptions.count,
                                                                  reason: reason))
                return true
            }
        }
    }

    // MARK: - Queue helpers (on `syncQueue` only)

    private static let idKey = "id"
    private static let recordsKey = "records"
    private static let windowStartKey = "window_start"
    private static let sequenceDigits = 12
    private static let batchSuffix = ".json"
    private static let migratedMarkerName = "_migrated"
    private static let ownerKey = "sensorkit.owner"
    private static let ownerSinceKey = "sensorkit.owner_since"
    private static let ownerContentKey = "owner"
    /// Quarantined items are deleted after this long (owner rule 6).
    static let quarantineRetention: TimeInterval = 7 * 24 * 60 * 60
    private static let quarantineDirectoryName = "_quarantine"

    private struct BatchFile {
        let sequence: Int
        let id: String
        let url: URL
    }

    private enum BatchRead {
        case batch(SensorQueuedBatch)
        /// No such file: the index is stale.
        case missing
        case unreadable
        case unparseable
    }

    /// `{"ids": [...], "digests": [...]}`: the batch ids and the SHA-256 of every legacy blob fully
    /// migrated for one sensor (plan R2 PR-2). Never deleted by the SDK.
    private struct MigrationMarker: Codable {
        var ids: Set<String> = []
        var digests: Set<String> = []
    }

    private func legacyQueueKey(_ sensor: SRSensor) -> String {
        return self.queueKeyPrefix + sensor.rawValue
    }

    private func sensorDirectory(_ sensor: SRSensor) -> URL {
        return self.queueRoot.appendingPathComponent(sensor.rawValue, isDirectory: true)
    }

    private var quarantineDirectory: URL {
        return self.queueRoot.appendingPathComponent(Self.quarantineDirectoryName, isDirectory: true)
    }

    private func markerURL(_ sensor: SRSensor) -> URL {
        return self.sensorDirectory(sensor).appendingPathComponent(Self.migratedMarkerName)
    }

    static func batchName(sequence: Int, id: String) -> String {
        let digits = String(sequence)
        return String(repeating: "0", count: max(0, Self.sequenceDigits - digits.count)) + digits + "_" + id + Self.batchSuffix
    }

    /// `^\d{12}_[^/]+\.json$`; anything else (atomic-write temp files `<name>.sb-<hash>-<random>`,
    /// `.DS_Store`, the markers) is not a batch, so it is never listed, peeked or uploaded.
    private static func parseBatchName(_ name: String, in directory: URL) -> BatchFile? {
        guard name.hasSuffix(Self.batchSuffix), name.count > Self.sequenceDigits + 1 + Self.batchSuffix.count else { return nil }
        let digits = name.prefix(Self.sequenceDigits)
        guard digits.allSatisfy({ $0.isASCII && $0.isNumber }),
              name.dropFirst(Self.sequenceDigits).first == "_",
              let sequence = Int(digits) else { return nil }
        let id = String(name.dropFirst(Self.sequenceDigits + 1).dropLast(Self.batchSuffix.count))
        return BatchFile(sequence: sequence, id: id, url: directory.appendingPathComponent(name))
    }

    /// An id usable inside a file name. A legacy entry whose id is not gets a content id instead.
    private static func isFileSafeId(_ id: String?) -> Bool {
        guard let id = id, !id.isEmpty, id.count <= 128 else { return false }
        return !id.contains("/") && !id.contains("\0") && !id.hasPrefix(".")
    }

    static func sha256Hex(_ data: Data) -> String {
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// One entry of the 0.101.16/17 `UserDefaults` array, or one batch file: the entry parser of the
    /// old `loadQueue`, unchanged. `nil` for the pre-FUAM-3945 shape (no window start).
    private static func queuedBatch(from entry: [String: Any], id: String) -> SensorQueuedBatch? {
        guard let records = entry[Self.recordsKey] as? [[String: Any]],
              let windowStart = entry[Self.windowStartKey] as? Double else { return nil }
        return SensorQueuedBatch(id: id,
                                 records: records,
                                 windowStart: Date(timeIntervalSince1970: windowStart),
                                 owner: entry[Self.ownerContentKey] as? String)
    }

    /// At the first queue access of the process, delete every leftover of an interrupted atomic
    /// write. No write can be in flight then (one storage instance, every write on `syncQueue`), so
    /// anything in the queue directories that is not a batch file, a marker or a quarantined file is
    /// such a leftover. Foundation names the temp file `<target>.sb-<hash>-<random>`, in the target
    /// directory and NOT hidden (review A-1, observed on the iOS simulator runtime), so matching on
    /// hidden names alone never removed one. Kept: in a sensor directory, `<seq>_<id>.json` and
    /// `_migrated`; at the root, directories (sensors, `_quarantine`); in `_quarantine`, names
    /// ending in `.json`. Quarantined items older than `quarantineRetention` are deleted here too
    /// (owner rule 6), by the time written into their name when they were set aside. No
    /// file-timestamp API is used: it would be a required-reason API (plan R2 PR-18 item 2).
    private func prepareRootIfNeeded() {
        guard !self.rootPrepared else { return }
        self.rootPrepared = true
        guard let children = try? self.fileManager.contentsOfDirectory(atPath: self.queueRoot.path) else { return }
        for child in children {
            let url = self.queueRoot.appendingPathComponent(child)
            var isDirectory: ObjCBool = false
            guard self.fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            guard isDirectory.boolValue, !child.hasPrefix(".") else {
                try? self.fileManager.removeItem(at: url)
                continue
            }
            let isQuarantine = child == Self.quarantineDirectoryName
            var expired = 0
            for name in (try? self.fileManager.contentsOfDirectory(atPath: url.path)) ?? [] {
                let keep: Bool
                if isQuarantine {
                    let isItem = name.hasSuffix(Self.batchSuffix) && !name.hasPrefix(".")
                    let isExpired = Self.quarantinedAt(name).map { Date().timeIntervalSince($0) > Self.quarantineRetention } ?? false
                    if isItem, isExpired { expired += 1 }
                    keep = isItem && !isExpired
                } else {
                    keep = name == Self.migratedMarkerName || Self.parseBatchName(name, in: url) != nil
                }
                if !keep { try? self.fileManager.removeItem(at: url.appendingPathComponent(name)) }
            }
            if expired > 0 {
                self.analytics?.track(event: .sensorRecordDropped(sensor: "sensorkit", count: expired, reason: "quarantine_expired"))
            }
        }
    }

    /// `q<epoch seconds>_<sensor>_<item>_<reason>.json`: the time is written into the name when
    /// the item is set aside, so expiry needs no file-timestamp API.
    private static func quarantineName(sensor: SRSensor, item: String, reason: String) -> String {
        return "q\(Int(Date().timeIntervalSince1970))_\(sensor.rawValue)_\(item)_\(reason)\(Self.batchSuffix)"
    }

    /// The time a quarantined item was set aside, `nil` for a name without one (kept: never
    /// delete on an inference).
    private static func quarantinedAt(_ name: String) -> Date? {
        guard name.hasPrefix("q"), let end = name.firstIndex(of: "_"),
              let seconds = TimeInterval(name[name.index(after: name.startIndex)..<end]) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// Created with `completeUntilFirstUserAuthentication`: readable and writable while the screen
    /// is locked after the first unlock since boot, which the grace-period uploads need.
    private func ensureDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if self.fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        do {
            try self.fileManager.createDirectory(at: url,
                                                 withIntermediateDirectories: true,
                                                 attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    /// Batch files sorted by sequence (queue order). `[]` when the directory does not exist yet;
    /// `nil` when it exists but cannot be listed (protection or permission error).
    private func listBatches(_ sensor: SRSensor) -> [BatchFile]? {
        self.directoryListings += 1
        let directory = self.sensorDirectory(sensor)
        let names: [String]
        do {
            names = try self.fileManager.contentsOfDirectory(atPath: directory.path)
        } catch {
            return self.fileManager.fileExists(atPath: directory.path) ? nil : []
        }
        return names.compactMap { Self.parseBatchName($0, in: directory) }.sorted { $0.sequence < $1.sequence }
    }

    /// The index of `sensor`'s batch files, built from one listing when absent. `nil` when the
    /// directory cannot be listed (nothing is cached then, so the next call lists again).
    private func indexedBatches(_ sensor: SRSensor) -> [BatchFile]? {
        if let cached = self.batchIndex[sensor.rawValue] { return cached }
        guard let listed = self.listBatches(sensor) else { return nil }
        self.batchIndex[sensor.rawValue] = listed
        return listed
    }

    /// Unlinks a batch file and drops it from the index. `true` when the file is gone.
    private func unlink(_ file: BatchFile, for sensor: SRSensor) -> Bool {
        try? self.fileManager.removeItem(at: file.url)
        guard !self.fileManager.fileExists(atPath: file.url.path) else { return false }
        self.batchIndex[sensor.rawValue]?.removeAll { $0.id == file.id }
        return true
    }

    /// Retries the removals that failed earlier in this process (review A-5).
    private func retryPendingRemovals(_ sensor: SRSensor) {
        guard let pending = self.pendingRemovals[sensor.rawValue], !pending.isEmpty else { return }
        let files = self.indexedBatches(sensor) ?? []
        for id in pending {
            guard let file = files.first(where: { $0.id == id }) else {
                self.pendingRemovals[sensor.rawValue]?.remove(id) // already gone
                continue
            }
            if self.unlink(file, for: sensor) { self.pendingRemovals[sensor.rawValue]?.remove(id) }
        }
    }

    /// Directory listings of sensor directories so far. Internal for the index spec only.
    var directoryListingCount: Int {
        return self.syncQueue.sync { self.directoryListings }
    }

    private func takeSequence(for sensor: SRSensor) -> Int? {
        let next: Int
        if let cached = self.nextSequence[sensor.rawValue] {
            next = cached
        } else {
            guard let listed = self.indexedBatches(sensor) else { return nil }
            next = (listed.last?.sequence ?? 0) + 1
        }
        self.nextSequence[sensor.rawValue] = next + 1
        return next
    }

    private func write(_ data: Data, to url: URL) -> Bool {
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    private func writeJSON(_ object: Any, to url: URL) -> Bool {
        guard let data = Self.serialized(object) else { return false }
        return self.write(data, to: url)
    }

    /// The compact JSON of `object`, `nil` when `JSONSerialization` rejects it.
    private static func serialized(_ object: Any) -> Data? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    /// FUAM-4517: `.unserializable` when the content cannot be serialized, `.writeFailed` on any
    /// file-system error (directory, sequence listing, write); either way nothing was written.
    private func writeNewBatch(id: String, records: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> SensorEnqueueOutcome {
        var content: [String: Any] = [Self.idKey: id,
                                      Self.windowStartKey: windowStart.timeIntervalSince1970,
                                      Self.recordsKey: records]
        content[Self.ownerContentKey] = self.owner
        guard let data = Self.serialized(content) else { return .unserializable }
        return self.writeBatchData(data, id: id, for: sensor) ? .enqueued(id: id) : .writeFailed
    }

    /// Writes `content` as the new tail batch `<next seq>_<id>.json` and adds it to the index.
    private func writeBatchFile(_ content: [String: Any], id: String, for sensor: SRSensor) -> Bool {
        guard let data = Self.serialized(content) else { return false }
        return self.writeBatchData(data, id: id, for: sensor)
    }

    private func writeBatchData(_ data: Data, id: String, for sensor: SRSensor) -> Bool {
        let directory = self.sensorDirectory(sensor)
        guard self.ensureDirectory(directory), let sequence = self.takeSequence(for: sensor) else { return false }
        let url = directory.appendingPathComponent(Self.batchName(sequence: sequence, id: id))
        guard self.write(data, to: url) else { return false }
        self.batchIndex[sensor.rawValue]?.append(BatchFile(sequence: sequence, id: id, url: url))
        return true
    }

    private func readBatch(_ file: BatchFile) -> BatchRead {
        let data: Data
        do {
            data = try Data(contentsOf: file.url)
        } catch {
            let code = (error as NSError).code
            return code == NSFileReadNoSuchFileError || code == NSFileNoSuchFileError ? .missing : .unreadable
        }
        guard let entry = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let batch = Self.queuedBatch(from: entry, id: file.id) else { return .unparseable }
        return .batch(batch)
    }

    /// Moves a batch file that was read and is invalid to `<queueRoot>/_quarantine/`: never
    /// uploaded, deleted after `quarantineRetention` (owner rule 6). The id is part of the name,
    /// so two quarantined files never collide. Telemetry: `sensor_record_dropped` with the
    /// reason, where `count` is one BATCH. `false` when the move failed.
    @discardableResult
    private func quarantine(_ file: BatchFile, sensor: SRSensor, reason: String) -> Bool {
        guard self.ensureDirectory(self.quarantineDirectory) else { return false }
        let name = Self.quarantineName(sensor: sensor, item: file.url.deletingPathExtension().lastPathComponent, reason: reason)
        do {
            try self.fileManager.moveItem(at: file.url, to: self.quarantineDirectory.appendingPathComponent(name))
        } catch {
            return false
        }
        self.batchIndex[sensor.rawValue]?.removeAll { $0.id == file.id }
        self.analytics?.track(event: .sensorRecordDropped(sensor: sensor.shortSubsource, count: 1, reason: reason))
        return true
    }

    /// `nil` when the marker exists but cannot be read (undecidable: the caller must not migrate).
    /// A marker that reads but does not decode is treated as empty: at worst an already migrated
    /// batch is migrated and uploaded once more, which the server drops by identity; never a loss.
    private func readMarker(_ sensor: SRSensor) -> MigrationMarker? {
        let url = self.markerURL(sensor)
        guard self.fileManager.fileExists(atPath: url.path) else { return MigrationMarker() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONDecoder().decode(MigrationMarker.self, from: data)) ?? MigrationMarker()
    }

    private func writeMarker(_ marker: MigrationMarker, for sensor: SRSensor) -> Bool {
        guard self.ensureDirectory(self.sensorDirectory(sensor)),
              let data = try? JSONEncoder().encode(marker) else { return false }
        return self.write(data, to: self.markerURL(sensor))
    }

    // MARK: - Legacy queue migration (FUAM-4516, plan §2.1 as amended by R2 PR-2 and PR-18)

    /// `true` once the sensor's legacy queue is migrated or absent. Runs the migration at most once
    /// per process; until it succeeds, the sensor's queue reads as empty.
    private func ensureMigrated(_ sensor: SRSensor) -> Bool {
        let raw = sensor.rawValue
        if self.migratedSensors.contains(raw) { return true }
        // Owner rule 1: migrated batches are stamped with the participant; with no session there
        // is none, so the migration does not run (and is not counted as attempted).
        guard self.owner != nil else { return false }
        guard !self.migrationAttempted.contains(raw) else { return false }
        self.migrationAttempted.insert(raw)
        let migrated = autoreleasepool { self.migrateLegacyQueue(sensor) }
        if migrated { self.migratedSensors.insert(raw) }
        return migrated
    }

    /// File-system authoritative: the `_migrated` marker is written only after every batch file,
    /// and lists the digest of the blob, so a key whose removal did not persist is recognised and
    /// never migrated (or uploaded) twice. Absent key: nothing to do and NOTHING is stored, which is
    /// also what happens before the first unlock, when `UserDefaults` reads return nil.
    private func migrateLegacyQueue(_ sensor: SRSensor) -> Bool {
        let key = self.legacyQueueKey(sensor)
        guard let data = UserDefaults.standard.data(forKey: key) else { return true }
        let digest = Self.sha256Hex(data)
        guard var marker = self.readMarker(sensor) else { return false }
        if marker.digests.contains(digest) {
            // Already migrated: the removal did not persist. Do not parse it.
            UserDefaults.standard.removeObject(forKey: key)
            return true
        }

        guard let entries = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
            // The only case where queued data cannot be uploaded: kept in quarantine, not deleted.
            let name = Self.quarantineName(sensor: sensor, item: "legacy-\(digest.prefix(16))", reason: "legacy_unparseable")
            marker.digests.insert(digest)
            guard self.ensureDirectory(self.quarantineDirectory),
                  self.write(data, to: self.quarantineDirectory.appendingPathComponent(name)),
                  self.writeMarker(marker, for: sensor) else {
                self.trackMigration(sensor, batchCount: 0, legacyBytes: data.count, outcome: "partial_disk_error")
                return false
            }
            UserDefaults.standard.removeObject(forKey: key)
            self.trackMigration(sensor, batchCount: 0, legacyBytes: data.count, outcome: "unparseable")
            return true
        }

        let directory = self.sensorDirectory(sensor)
        guard self.ensureDirectory(directory), let listed = self.indexedBatches(sensor) else {
            self.trackMigration(sensor, batchCount: 0, legacyBytes: data.count, outcome: "partial_disk_error")
            return false
        }
        var existingIds = Set(listed.map { $0.id })
        var entryIds: [String] = []
        var written = 0
        var droppedRecords = 0
        var writeFailed = false
        for (index, entry) in entries.enumerated() {
            writeFailed = autoreleasepool { () -> Bool in
                guard let dictionary = entry as? [String: Any],
                      Self.queuedBatch(from: dictionary, id: "") != nil else {
                    // Pre-FUAM-3945 shape (no window start): dropped, the policy 0.101.16 already
                    // applied on load. A bare array of records counts its records.
                    droppedRecords += (entry as? [Any])?.count ?? 1
                    return false
                }
                let ownId = dictionary[Self.idKey] as? String
                let id = Self.isFileSafeId(ownId) ? (ownId ?? "") : Self.legacyContentId(of: dictionary, blobDigest: digest, index: index)
                entryIds.append(id)
                // A re-run after an interruption: the file is already there (or was migrated,
                // uploaded and deleted before the key removal got lost).
                guard !marker.ids.contains(id), !existingIds.contains(id) else { return false }
                var content = dictionary
                content[Self.idKey] = id
                content[Self.ownerContentKey] = self.owner
                guard self.writeBatchFile(content, id: id, for: sensor) else { return true }
                existingIds.insert(id)
                written += 1
                return false
            }
            if writeFailed { break }
        }
        if droppedRecords > 0 {
            self.analytics?.track(event: .sensorRecordDropped(sensor: sensor.shortSubsource,
                                                              count: droppedRecords,
                                                              reason: "legacy_queue_entry"))
        }
        guard !writeFailed else {
            // Stop, keep the key: the next launch resumes, skipping the files written so far.
            self.trackMigration(sensor, batchCount: written, legacyBytes: data.count, outcome: "partial_disk_error")
            return false
        }
        marker.ids.formUnion(entryIds)
        marker.digests.insert(digest)
        guard self.writeMarker(marker, for: sensor) else {
            self.trackMigration(sensor, batchCount: written, legacyBytes: data.count, outcome: "partial_disk_error")
            return false
        }
        UserDefaults.standard.removeObject(forKey: key)
        self.trackMigration(sensor, batchCount: written, legacyBytes: data.count, outcome: "ok")
        return true
    }

    /// The id of a legacy entry that has none: a hash of its content, so it is stable across an
    /// interrupted re-run and across reordering (plan R2 PR-18 item 1). Identical id-less entries
    /// share an id, and the second is skipped: same records, same window, nothing lost.
    private static func legacyContentId(of entry: [String: Any], blobDigest: String, index: Int) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else {
            // Unreachable for an entry parsed from JSON; still deterministic.
            return "legacy-\(blobDigest.prefix(16))-\(index)"
        }
        return "legacy-" + String(Self.sha256Hex(data).prefix(16))
    }

    private func trackMigration(_ sensor: SRSensor, batchCount: Int, legacyBytes: Int, outcome: String) {
        self.analytics?.track(event: .sensorQueueMigrated(sensor: sensor.shortSubsource,
                                                          batchCount: batchCount,
                                                          legacyBytes: legacyBytes,
                                                          outcome: outcome))
    }
}
