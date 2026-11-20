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

    public init(id: String, records: [[String: Any]], windowStart: Date) {
        self.id = id
        self.records = records
        self.windowStart = windowStart
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

    /// The head of the queue with the window it was fetched from, REMOVED from the queue, or
    /// `nil` when the queue is empty. Only for dropping batches (`purgeAllData`): an upload
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
        return self.syncQueue.sync {
            autoreleasepool {
                self.prepareRootIfNeeded()
                _ = self.ensureMigrated(sensor)
                // FUAM-4517 seam: the id is chosen here so a rollback of a partially enqueued
                // window can remove exactly what it wrote.
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
                guard self.ensureMigrated(sensor), let listed = self.listBatches(sensor) else { return nil }
                for file in listed where !ids.contains(file.id) {
                    switch self.readBatch(file) {
                    case .batch(let batch):
                        return batch
                    case .unreadable:
                        // Protection or permission error: leave the queue idle, lose nothing.
                        return nil
                    case .unparseable:
                        // Kept, never uploaded, never auto-deleted; the drain moves on.
                        self.quarantine(file, sensor: sensor, reason: "batch_unparseable")
                    }
                }
                return nil
            }
        }
    }

    public func removeBatch(id: String, for sensor: SRSensor) {
        self.syncQueue.sync {
            autoreleasepool {
                self.prepareRootIfNeeded()
                guard let file = self.listBatches(sensor)?.first(where: { $0.id == id }) else { return }
                try? self.fileManager.removeItem(at: file.url)
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
                guard let listed = self.listBatches(sensor) else { return false }
                guard let file = listed.first(where: { $0.id == id }) else { return true }
                guard case .batch(let current) = self.readBatch(file) else { return false }
                if !(current.records as NSArray).isEqual(to: records) {
                    let content: [String: Any] = [Self.idKey: id,
                                                  Self.windowStartKey: current.windowStart.timeIntervalSince1970,
                                                  Self.recordsKey: records]
                    guard self.writeJSON(content, to: file.url) else { return false }
                }
                guard let sequence = self.takeSequence(for: sensor) else { return false }
                let tail = self.sensorDirectory(sensor).appendingPathComponent(Self.batchName(sequence: sequence, id: id))
                do {
                    try self.fileManager.moveItem(at: file.url, to: tail)
                    return true
                } catch {
                    return false
                }
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
            return self.listBatches(sensor)?.count ?? 0
        }
    }

    // MARK: - Queue helpers (on `syncQueue` only)

    private static let idKey = "id"
    private static let recordsKey = "records"
    private static let windowStartKey = "window_start"
    private static let sequenceDigits = 12
    private static let batchSuffix = ".json"
    private static let migratedMarkerName = "_migrated"
    private static let quarantineDirectoryName = "_quarantine"

    private struct BatchFile {
        let sequence: Int
        let id: String
        let url: URL
    }

    private enum BatchRead {
        case batch(SensorQueuedBatch)
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

    /// `^\d{12}_[^/]+\.json$`; anything else (atomic-write temp files, `.DS_Store`, the markers) is
    /// not a batch.
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
        return SensorQueuedBatch(id: id, records: records, windowStart: Date(timeIntervalSince1970: windowStart))
    }

    /// At the first queue access of the process, delete every hidden file in the queue
    /// directories. No write can be in flight then (one storage instance, every write on
    /// `syncQueue`), so a hidden file is the temp file of an atomic write a kill interrupted. No
    /// file-timestamp API is used: it would be a required-reason API (plan R2 PR-18 item 2).
    private func prepareRootIfNeeded() {
        guard !self.rootPrepared else { return }
        self.rootPrepared = true
        guard let children = try? self.fileManager.contentsOfDirectory(atPath: self.queueRoot.path) else { return }
        for child in children {
            let url = self.queueRoot.appendingPathComponent(child)
            if child.hasPrefix(".") {
                try? self.fileManager.removeItem(at: url)
                continue
            }
            for name in (try? self.fileManager.contentsOfDirectory(atPath: url.path)) ?? [] where name.hasPrefix(".") {
                try? self.fileManager.removeItem(at: url.appendingPathComponent(name))
            }
        }
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
        let directory = self.sensorDirectory(sensor)
        let names: [String]
        do {
            names = try self.fileManager.contentsOfDirectory(atPath: directory.path)
        } catch {
            return self.fileManager.fileExists(atPath: directory.path) ? nil : []
        }
        return names.compactMap { Self.parseBatchName($0, in: directory) }.sorted { $0.sequence < $1.sequence }
    }

    private func takeSequence(for sensor: SRSensor) -> Int? {
        let next: Int
        if let cached = self.nextSequence[sensor.rawValue] {
            next = cached
        } else {
            guard let listed = self.listBatches(sensor) else { return nil }
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
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object) else { return false }
        return self.write(data, to: url)
    }

    /// `false` on any serialization or file-system error (AC4): the caller leaves the cursor alone.
    private func writeNewBatch(id: String, records: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> Bool {
        let directory = self.sensorDirectory(sensor)
        guard self.ensureDirectory(directory), let sequence = self.takeSequence(for: sensor) else { return false }
        let content: [String: Any] = [Self.idKey: id,
                                      Self.windowStartKey: windowStart.timeIntervalSince1970,
                                      Self.recordsKey: records]
        return self.writeJSON(content, to: directory.appendingPathComponent(Self.batchName(sequence: sequence, id: id)))
    }

    private func readBatch(_ file: BatchFile) -> BatchRead {
        guard let data = try? Data(contentsOf: file.url) else { return .unreadable }
        guard let entry = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let batch = Self.queuedBatch(from: entry, id: file.id) else { return .unparseable }
        return .batch(batch)
    }

    /// Moves unparseable bytes to `<queueRoot>/_quarantine/`: never uploaded, never auto-deleted,
    /// deleted only by a purge (plan OQ6). The id is part of the name, so two quarantined files
    /// never collide even when a sequence number is reused after the queue emptied.
    private func quarantine(_ file: BatchFile, sensor: SRSensor, reason: String) {
        guard self.ensureDirectory(self.quarantineDirectory) else { return }
        let name = "\(sensor.rawValue)_\(file.url.deletingPathExtension().lastPathComponent)_\(reason).json"
        do {
            try self.fileManager.moveItem(at: file.url, to: self.quarantineDirectory.appendingPathComponent(name))
        } catch {
            return
        }
        // `count` is one quarantined BATCH: its record count is unknowable.
        self.analytics?.track(event: .sensorRecordDropped(sensor: sensor.shortSubsource, count: 1, reason: reason))
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
            let name = "\(sensor.rawValue)_legacy-\(digest.prefix(16))_legacy_unparseable.json"
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
        guard self.ensureDirectory(directory), let listed = self.listBatches(sensor) else {
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
                guard let sequence = self.takeSequence(for: sensor),
                      self.writeJSON(content, to: directory.appendingPathComponent(Self.batchName(sequence: sequence, id: id))) else {
                    return true
                }
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
