//
//  SensorQueueFileStorageSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4516: the SensorKit upload queue as one file per batch (plan §2.1, §3.1, §4.1, Revisions
//  2-4). Every spec runs on its own temp queue directory; the legacy `UserDefaults` keys it touches
//  are removed in `afterEach`.
//
//  - `SensorQueueFileStorageSpec`: the storage alone (queue operations, directory hygiene,
//    quarantine, migration of a 0.101.16/17 queue, purge support).
//  - `SensorQueueDrainSpec`: the upload manager over that storage (one upload in flight per
//    sensor, requeue, the 1 MiB cap, the memory guard, the probe byte budget, the kill-safe purge).
//

import Quick
import Nimble
import RxSwift
import SensorKit
@testable import ForYouAndMe

// MARK: - Helpers

private enum QueueFixture {

    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 24 * hour

    static func makeRoot() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fuam4516-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func removeRoot(_ url: URL) {
        // Undo any permission change a spec made, so the directory can be deleted.
        if let enumerator = FileManager.default.enumerator(atPath: url.path) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            for case let path as String in enumerator {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                       ofItemAtPath: url.appendingPathComponent(path).path)
            }
        }
        for name in (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [] {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                   ofItemAtPath: url.appendingPathComponent(name).path)
        }
        try? FileManager.default.removeItem(at: url)
    }

    static func legacyKey(_ sensor: SRSensor) -> String {
        return "sensorkit.queue." + sensor.rawValue
    }

    /// Every `UserDefaults` key the specs may write for `sensor`.
    static func clearDefaults(_ sensor: SRSensor) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: legacyKey(sensor))
        defaults.removeObject(forKey: "sensorkit.cursor." + sensor.rawValue)
        defaults.removeObject(forKey: "sensorkit.cursor." + sensor.rawValue + ".watch")
        defaults.removeObject(forKey: "sensorkit.ledger." + sensor.rawValue)
        defaults.removeObject(forKey: "sensorkit.rescanday." + sensor.rawValue + ".iphone")
        defaults.removeObject(forKey: "sensorkit.deepestwindow." + sensor.rawValue + ".iphone")
    }

    @discardableResult
    static func seedLegacy(_ entries: [Any], for sensor: SRSensor) -> Data {
        let data = (try? JSONSerialization.data(withJSONObject: entries)) ?? Data()
        UserDefaults.standard.set(data, forKey: legacyKey(sensor))
        return data
    }

    static func sensorDirectory(_ root: URL, _ sensor: SRSensor) -> URL {
        return root.appendingPathComponent(sensor.rawValue, isDirectory: true)
    }

    /// Batch file names (`<12 digits>_<id>.json`) in queue order.
    static func batchFiles(_ root: URL, _ sensor: SRSensor) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: sensorDirectory(root, sensor).path)) ?? []
        return names.filter { name in
            name.hasSuffix(".json") && name.count > 18
                && name.prefix(12).allSatisfy { $0.isNumber } && name.dropFirst(12).first == "_"
        }.sorted()
    }

    static func batchIds(_ root: URL, _ sensor: SRSensor) -> [String] {
        return batchFiles(root, sensor).map { String($0.dropFirst(13).dropLast(5)) }
    }

    static func quarantined(_ root: URL) -> [String] {
        let url = root.appendingPathComponent("_quarantine", isDirectory: true)
        return ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
    }

    static func marker(_ root: URL, _ sensor: SRSensor) -> (ids: Set<String>, digests: Set<String>)? {
        let url = sensorDirectory(root, sensor).appendingPathComponent("_migrated")
        guard let data = try? Data(contentsOf: url),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return (Set(object["ids"] as? [String] ?? []), Set(object["digests"] as? [String] ?? []))
    }

    /// One record shaped like the harness seed (`seed.py`): a 15-minute device-usage-like report
    /// carrying 60 per-app dictionaries, about 6.5 KB of JSON.
    static func seedRecord(_ index: Int, day: Date) -> [String: Any] {
        let start = day.addingTimeInterval(TimeInterval(15 * 60 * (index % 96)))
        let apps: [[String: Any]] = (0..<60).map { app in
            ["bundle_identifier": "com.vendor.app\(app)",
             "usage_s": Double((index * 7 + app) % 900),
             "category": "productivity",
             "text_input_sessions": [Any]()]
        }
        return ["recorded_at": ISO8601DateFormatter().string(from: start.addingTimeInterval(900)),
                "duration_s": 900,
                "device_kind": "iphone",
                "device_product_type": "iPhone18,1",
                "device_os_version": "27.0",
                "seq": index,
                "apps": apps]
    }

    /// A legacy queue entry whose serialized size reaches `targetBytes`, as `seed.py` builds it.
    static func legacyEntry(targetBytes: Int, day: Date, id: String = UUID().uuidString) -> [String: Any] {
        let one = (try? JSONSerialization.data(withJSONObject: seedRecord(0, day: day)))?.count ?? 6_500
        let count = max(1, targetBytes / (one + 1))
        let records = (0..<count).map { seedRecord($0, day: day) }
        return ["id": id, "window_start": day.timeIntervalSince1970, "records": records]
    }

    static func iso(_ date: Date) -> String {
        return ISO8601DateFormatter().string(from: date)
    }

    /// A raw device-usage report the size of hers (plan R5: the shape stays raw): 3,274 `web`
    /// entries of which 43 are distinct, about 200 KB of JSON.
    static func heavyReport(_ index: Int, at date: Date) -> [String: Any] {
        let web: [[String: Any]] = (0..<3_274).map { entry in
            ["category": "com.apple.web-category.\(entry % 43)", "usage_s": 900]
        }
        return ["t": iso(date), "recorded_at": iso(date.addingTimeInterval(900)), "duration_s": 900,
                "seq": index, "web": web]
    }
}

/// A storage that records the order of the purge-relevant calls, delegating everything to a real
/// `DefaultsSensorStorage`.
private final class OrderRecordingStorage: SensorSampleUploadManagerStorage, SensorSampleUploaderStorage {

    private let base: DefaultsSensorStorage
    private let lock = NSLock()
    private var log: [String] = []

    init(base: DefaultsSensorStorage) { self.base = base }

    var calls: [String] {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.log
    }

    private func record(_ call: String) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.log.append(call)
    }

    func lastCursor(for sensor: SRSensor, deviceKey: String) -> Date? { base.lastCursor(for: sensor, deviceKey: deviceKey) }
    func setLastCursor(_ date: Date, for sensor: SRSensor, deviceKey: String) {
        self.record("setLastCursor")
        base.setLastCursor(date, for: sensor, deviceKey: deviceKey)
    }
    func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> Bool {
        return base.enqueueBatch(batch, windowStart: windowStart, for: sensor)
    }
    func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)? {
        self.record("dequeueNextBatch")
        return base.dequeueNextBatch(for: sensor)
    }
    func peekNextBatch(for sensor: SRSensor, excluding ids: Set<String>) -> SensorQueuedBatch? {
        return base.peekNextBatch(for: sensor, excluding: ids)
    }
    func removeBatch(id: String, for sensor: SRSensor) {
        self.record("removeBatch")
        base.removeBatch(id: id, for: sensor)
    }
    func requeueBatch(id: String, records: [[String: Any]], for sensor: SRSensor) -> Bool {
        return base.requeueBatch(id: id, records: records, for: sensor)
    }
    func pendingBatchCount(for sensor: SRSensor) -> Int { base.pendingBatchCount(for: sensor) }
    func ledger(for sensor: SRSensor, deviceKey: String) -> [String: SensorLedgerEntry] {
        return base.ledger(for: sensor, deviceKey: deviceKey)
    }
    func setLedger(_ ledger: [String: SensorLedgerEntry], for sensor: SRSensor, deviceKey: String) {
        base.setLedger(ledger, for: sensor, deviceKey: deviceKey)
    }
    func purgeLedger(for sensor: SRSensor) {
        self.record("purgeLedger")
        base.purgeLedger(for: sensor)
    }
    func lastRescanDay(for sensor: SRSensor, deviceKey: String) -> Date? { base.lastRescanDay(for: sensor, deviceKey: deviceKey) }
    func setLastRescanDay(_ day: Date, for sensor: SRSensor, deviceKey: String) {
        base.setLastRescanDay(day, for: sensor, deviceKey: deviceKey)
    }
    func deepestProductiveWindowStart(for sensor: SRSensor, deviceKey: String) -> Date? {
        return base.deepestProductiveWindowStart(for: sensor, deviceKey: deviceKey)
    }
    func setDeepestProductiveWindowStart(_ date: Date, for sensor: SRSensor, deviceKey: String) {
        base.setDeepestProductiveWindowStart(date, for: sensor, deviceKey: deviceKey)
    }
    func forEachQueuedBatch(for sensor: SRSensor, _ body: (SensorQueuedBatch) -> Void) {
        self.record("forEachQueuedBatch")
        base.forEachQueuedBatch(for: sensor, body)
    }
    func deleteQueue(for sensor: SRSensor) -> Bool {
        self.record("deleteQueue")
        return base.deleteQueue(for: sensor)
    }
    var isPurgePending: Bool { base.isPurgePending }
    func setPurgePending(_ pending: Bool) -> Bool {
        self.record("setPurgePending(\(pending))")
        return base.setPurgePending(pending)
    }
}

/// Uploads complete after `delay` on a background queue; records the highest number of requests
/// in flight at once, per sensor.
private final class ConcurrencyRecordingNetwork: SensorSampleUploaderNetworkDelegate {

    private let lock = NSLock()
    private var inFlight: [SRSensor: Int] = [:]
    private var maxInFlight: [SRSensor: Int] = [:]
    private var payloads: [[[String: Any]]] = []
    private var attempts = 0

    var delay: TimeInterval = 0.05
    /// A non-nil error fails that upload.
    var errorForPayload: (([[String: Any]]) -> Error?)?

    var uploaded: [[[String: Any]]] {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.payloads
    }

    var attemptCount: Int {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.attempts
    }

    func maxConcurrent(for sensor: SRSensor) -> Int {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.maxInFlight[sensor] ?? 0
    }

    func uploadSensorBatch(sensor: SRSensor, payload: [[String: Any]]) -> Single<Void> {
        return Single.create { [weak self] observer in
            guard let self = self else { return Disposables.create() }
            self.lock.lock()
            self.attempts += 1
            let current = (self.inFlight[sensor] ?? 0) + 1
            self.inFlight[sensor] = current
            self.maxInFlight[sensor] = max(self.maxInFlight[sensor] ?? 0, current)
            self.lock.unlock()
            let error = self.errorForPayload?(payload)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + self.delay) {
                self.lock.lock()
                self.inFlight[sensor] = (self.inFlight[sensor] ?? 1) - 1
                if error == nil { self.payloads.append(payload) }
                self.lock.unlock()
                if let error = error {
                    observer(.failure(error))
                } else {
                    observer(.success(()))
                }
            }
            return Disposables.create()
        }
    }
}

// MARK: - The storage

// swiftlint:disable:next type_body_length
class SensorQueueFileStorageSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let sensor = SRSensor.deviceUsageReport
        let windowStart = Date(timeIntervalSince1970: 1_790_000_000)
        var root: URL!
        var analytics: CapturingAnalyticsService!
        var storage: DefaultsSensorStorage!

        func relaunch() -> DefaultsSensorStorage {
            return DefaultsSensorStorage(queueDirectory: root, analytics: analytics)
        }

        func marked(_ value: String) -> [[String: Any]] {
            return [["marker": value]]
        }

        func headMarker(_ storage: DefaultsSensorStorage) -> String? {
            return storage.peekNextBatch(for: sensor, excluding: [])?.records.first?["marker"] as? String
        }

        struct MigratedEvent {
            let count: Int
            let bytes: Int
            let outcome: String
        }

        func migratedEvents() -> [MigratedEvent] {
            return analytics.trackedEvents.compactMap { event in
                if case let .sensorQueueMigrated(_, count, bytes, outcome) = event {
                    return MigratedEvent(count: count, bytes: bytes, outcome: outcome)
                }
                return nil
            }
        }

        func droppedReasons() -> [String] {
            return analytics.trackedEvents.compactMap { event in
                if case let .sensorRecordDropped(_, _, reason) = event { return reason }
                return nil
            }
        }

        beforeEach {
            QueueFixture.clearDefaults(sensor)
            root = QueueFixture.makeRoot()
            analytics = CapturingAnalyticsService()
            storage = relaunch()
        }

        afterEach {
            QueueFixture.clearDefaults(sensor)
            QueueFixture.removeRoot(root)
        }

        describe("queue operations") {

            it("enqueue_peek_remove_is_fifo: order by sequence, removal by id (limit cases 1, 2)") {
                expect(storage.peekNextBatch(for: sensor, excluding: [])).to(beNil())
                expect(storage.pendingBatchCount(for: sensor)).to(equal(0))

                expect(storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)).to(beTrue())
                expect(storage.enqueueBatch(marked("b"), windowStart: windowStart.addingTimeInterval(1), for: sensor)).to(beTrue())
                expect(storage.enqueueBatch(marked("c"), windowStart: windowStart.addingTimeInterval(2), for: sensor)).to(beTrue())
                expect(storage.pendingBatchCount(for: sensor)).to(equal(3))
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(3))

                guard let head = storage.peekNextBatch(for: sensor, excluding: []) else { return fail("no head") }
                expect(head.records.first?["marker"] as? String).to(equal("a"))
                expect(head.windowStart).to(equal(windowStart))
                expect(storage.pendingBatchCount(for: sensor)).to(equal(3)) // peek removes nothing

                storage.removeBatch(id: head.id, for: sensor)
                storage.removeBatch(id: head.id, for: sensor) // a gone id is a no-op
                expect(headMarker(storage)).to(equal("b"))
                expect(storage.dequeueNextBatch(for: sensor)?.records.first?["marker"] as? String).to(equal("b"))
                expect(storage.dequeueNextBatch(for: sensor)?.records.first?["marker"] as? String).to(equal("c"))
                expect(storage.dequeueNextBatch(for: sensor)).to(beNil())
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
            }

            it("peek_reads_only_the_head_file: every other file may be garbage") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("c"), windowStart: windowStart, for: sensor)
                let directory = QueueFixture.sensorDirectory(root, sensor)
                for name in QueueFixture.batchFiles(root, sensor).dropFirst() {
                    try? Data("not json at all".utf8).write(to: directory.appendingPathComponent(name))
                }

                expect(headMarker(relaunch())).to(equal("a"))
                // Had a non-head file been opened, it would have been quarantined.
                expect(QueueFixture.quarantined(root)).to(beEmpty())
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(3))
            }

            it("requeue_moves_the_batch_to_the_tail_keeping_its_id") {
                storage.enqueueBatch([["marker": "a"], ["marker": "a-dropped"]], windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                guard let head = storage.peekNextBatch(for: sensor, excluding: []) else { return fail("no head") }

                expect(storage.requeueBatch(id: head.id, records: marked("a"), for: sensor)).to(beTrue())

                expect(storage.pendingBatchCount(for: sensor)).to(equal(2))
                expect(QueueFixture.batchIds(root, sensor).filter { $0 == head.id }.count).to(equal(1))
                expect(headMarker(storage)).to(equal("b"))
                guard let second = storage.dequeueNextBatch(for: sensor) else { return fail("no b") }
                expect(second.records.first?["marker"] as? String).to(equal("b"))
                let requeued = storage.peekNextBatch(for: sensor, excluding: [])
                expect(requeued?.id).to(equal(head.id))
                expect(requeued?.records.count).to(equal(1))         // the FILTERED form
                expect(requeued?.windowStart).to(equal(windowStart)) // same window
            }

            it("requeue_state_after_kill_between_rewrite_and_rename_uploads_once") {
                // The state a kill leaves after the in-place rewrite and before the rename: the
                // filtered content still sits at the head position.
                let directory = QueueFixture.sensorDirectory(root, sensor)
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let first: [String: Any] = ["id": "batch-a", "window_start": windowStart.timeIntervalSince1970,
                                            "records": marked("a-filtered")]
                let second: [String: Any] = ["id": "batch-b", "window_start": windowStart.timeIntervalSince1970,
                                             "records": marked("b")]
                try? JSONSerialization.data(withJSONObject: first).write(to: directory.appendingPathComponent("000000000001_batch-a.json"))
                try? JSONSerialization.data(withJSONObject: second).write(to: directory.appendingPathComponent("000000000002_batch-b.json"))

                let relaunched = relaunch()
                expect(relaunched.pendingBatchCount(for: sensor)).to(equal(2))
                guard let head = relaunched.peekNextBatch(for: sensor, excluding: []) else { return fail("no head") }
                expect(head.id).to(equal("batch-a"))
                expect(head.records.first?["marker"] as? String).to(equal("a-filtered"))
                relaunched.removeBatch(id: head.id, for: sensor)
                expect(relaunched.peekNextBatch(for: sensor, excluding: [])?.id).to(equal("batch-b"))
                expect(QueueFixture.batchIds(root, sensor)).to(equal(["batch-b"]))
            }

            it("drains 2,000 batch files with a bounded number of directory listings (review B-5)") {
                for index in 0..<2_000 {
                    storage.enqueueBatch(marked("m\(index)"), windowStart: windowStart, for: sensor)
                }
                let relaunched = relaunch()
                var drained = 0
                var inOrder = true
                while let batch = relaunched.peekNextBatch(for: sensor, excluding: []) {
                    inOrder = inOrder && batch.records.first?["marker"] as? String == "m\(drained)"
                    relaunched.removeBatch(id: batch.id, for: sensor)
                    drained += 1
                }
                expect(drained).to(equal(2_000))
                expect(inOrder).to(beTrue())
                // One listing to build the index, one to confirm the queue is empty at the end.
                expect(relaunched.directoryListingCount).to(beLessThanOrEqualTo(3))
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
            }

            it("resolves an index the disk contradicts by re-listing, never by losing or duplicating") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(2)) // index built
                let directory = QueueFixture.sensorDirectory(root, sensor)
                // Behind the index's back: the head file disappears, a new tail file appears.
                guard let headName = QueueFixture.batchFiles(root, sensor).first else { return fail("no head") }
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(headName))
                let outside: [String: Any] = ["id": "outside", "window_start": windowStart.timeIntervalSince1970,
                                              "records": marked("c")]
                try? JSONSerialization.data(withJSONObject: outside)
                    .write(to: directory.appendingPathComponent("000000000099_outside.json"))

                var order: [String] = []
                while let batch = storage.peekNextBatch(for: sensor, excluding: []) {
                    order.append(batch.records.first?["marker"] as? String ?? "?")
                    storage.removeBatch(id: batch.id, for: sensor)
                }
                expect(order).to(equal(["b", "c"]))
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
            }

            it("requeue_after_purge_is_a_noop (limit case 43)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                guard let head = storage.peekNextBatch(for: sensor, excluding: []) else { return fail("no head") }
                storage.deleteQueue(for: sensor)

                expect(storage.requeueBatch(id: head.id, records: marked("a"), for: sensor)).to(beTrue())
                expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
            }

            it("order_survives_relaunch_and_clock_change: the sequence, not time, orders the queue (limit case 21)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("c"), windowStart: windowStart, for: sensor)
                // A clock moved around between writes: modification dates in reverse order.
                let directory = QueueFixture.sensorDirectory(root, sensor)
                for (offset, name) in QueueFixture.batchFiles(root, sensor).enumerated() {
                    let date = Date(timeIntervalSince1970: 2_000_000_000 - Double(offset) * 86_400)
                    try? FileManager.default.setAttributes([.modificationDate: date, .creationDate: date],
                                                           ofItemAtPath: directory.appendingPathComponent(name).path)
                }

                let relaunched = relaunch()
                relaunched.enqueueBatch(marked("d"), windowStart: windowStart, for: sensor)
                var order: [String] = []
                while let batch = relaunched.dequeueNextBatch(for: sensor) {
                    order.append(batch.records.first?["marker"] as? String ?? "?")
                }
                expect(order).to(equal(["a", "b", "c", "d"]))
            }

            it("interrupted_write_leftovers_are_never_batches_and_are_cleaned_at_first_access (limit case 20, review A-1)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                let directory = QueueFixture.sensorDirectory(root, sensor)
                let quarantine = root.appendingPathComponent("_quarantine", isDirectory: true)
                try? FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
                // Foundation's real atomic-write temp names: `<target>.sb-<hash>-<random>`, not hidden.
                let leftovers = [directory.appendingPathComponent("000000000002_abc.json.sb-e090b100-K2RmdU"),
                                 directory.appendingPathComponent("_migrated.sb-e090b100-7sCAzT"),
                                 directory.appendingPathComponent(".DS_Store"),
                                 directory.appendingPathComponent("notes.txt"),
                                 root.appendingPathComponent("_purge_pending.sb-e090b100-laUDDH"),
                                 quarantine.appendingPathComponent("x_000000000001_y_batch_unparseable.json.sb-e090b100-f5p7jG")]
                for url in leftovers {
                    try? Data("{\"id\": \"half".utf8).write(to: url)
                }
                let kept = quarantine.appendingPathComponent("x_000000000001_y_batch_unparseable.json")
                try? Data("kept".utf8).write(to: kept)

                // Before the first access a leftover is never read as a batch.
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(1))
                let relaunched = relaunch()
                expect(relaunched.pendingBatchCount(for: sensor)).to(equal(1))
                expect(headMarker(relaunched)).to(equal("a"))
                for url in leftovers {
                    expect(FileManager.default.fileExists(atPath: url.path)).to(beFalse())
                }
                expect(FileManager.default.fileExists(atPath: kept.path)).to(beTrue()) // quarantine is never auto-deleted
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(1))
            }

            it("corrupted_batch_is_quarantined_not_uploaded_not_deleted (limit case 19)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                let directory = QueueFixture.sensorDirectory(root, sensor)
                guard let headName = QueueFixture.batchFiles(root, sensor).first else { return fail("no head file") }
                let garbage = Data("{\"id\": \"truncated".utf8)
                try? garbage.write(to: directory.appendingPathComponent(headName))

                expect(headMarker(storage)).to(equal("b"))
                expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
                let quarantined = QueueFixture.quarantined(root)
                expect(quarantined.count).to(equal(1))
                expect(quarantined.first?.hasSuffix("_batch_unparseable.json")).to(beTrue())
                let kept = quarantined.first.flatMap {
                    try? Data(contentsOf: root.appendingPathComponent("_quarantine").appendingPathComponent($0))
                }
                expect(kept).to(equal(garbage))
                expect(droppedReasons()).to(contain("batch_unparseable"))
            }

            it("skips and quarantines a permanently unreadable batch file, traced (review B-7)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                guard let headName = QueueFixture.batchFiles(root, sensor).first else { return fail("no head") }
                let headURL = QueueFixture.sensorDirectory(root, sensor).appendingPathComponent(headName)
                try? FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: headURL.path)

                expect(headMarker(storage)).to(equal("b"))
                expect(FileManager.default.fileExists(atPath: headURL.path)).to(beFalse())
                expect(QueueFixture.quarantined(root).first?.hasSuffix("_batch_unreadable.json")).to(beTrue())
                expect(droppedReasons()).to(contain("batch_unreadable"))
            }

            it("leaves an unreadable batch file in place while protected data is unavailable (review B-7)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                guard let headName = QueueFixture.batchFiles(root, sensor).first else { return fail("no head") }
                let headURL = QueueFixture.sensorDirectory(root, sensor).appendingPathComponent(headName)
                try? FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: headURL.path)
                storage.isProtectedDataAvailable = { false }

                expect(storage.peekNextBatch(for: sensor, excluding: [])).to(beNil())
                expect(FileManager.default.fileExists(atPath: headURL.path)).to(beTrue())
                expect(QueueFixture.quarantined(root)).to(beEmpty())
                expect(droppedReasons()).to(beEmpty())
            }

            it("never peeks a batch again after its removal failed, and retries the removal (review A-5)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                storage.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)
                let directory = QueueFixture.sensorDirectory(root, sensor)
                guard let head = storage.peekNextBatch(for: sensor, excluding: []) else { return fail("no head") }
                try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }

                storage.removeBatch(id: head.id, for: sensor) // fails: the directory is read-only
                expect(QueueFixture.batchIds(root, sensor)).to(contain(head.id))
                expect(headMarker(storage)).to(equal("b"))
                expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
                expect(droppedReasons()).to(equal(["batch_remove_failed"]))

                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(1)) // the retry removed it
                expect(QueueFixture.batchIds(root, sensor)).toNot(contain(head.id))
            }

            it("read_error_yields_empty_peek_and_failed_enqueue (limit case 17)") {
                storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)
                let directory = QueueFixture.sensorDirectory(root, sensor)
                try? FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }

                let relaunched = relaunch()
                expect(relaunched.peekNextBatch(for: sensor, excluding: [])).to(beNil())
                expect(relaunched.enqueueBatch(marked("b"), windowStart: windowStart, for: sensor)).to(beFalse())

                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
                // Nothing was lost: readable again, the batch is still there.
                expect(headMarker(relaunch())).to(equal("a"))
            }

            it("write_error_returns_false (limit case 18, disk-full stand-in)") {
                // A file where the sensor's directory should be: every write fails. Placed after the
                // first access, whose cleanup would otherwise delete it as a leftover.
                _ = storage.pendingBatchCount(for: sensor)
                try? Data("x".utf8).write(to: QueueFixture.sensorDirectory(root, sensor))
                expect(storage.enqueueBatch(marked("a"), windowStart: windowStart, for: sensor)).to(beFalse())
                expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
            }

            it("survives a batch of exactly 1 MiB of records and keeps it intact (limit case 3)") {
                let blob = String(repeating: "x", count: SensorSampleUploadManager.maxBatchBytes - 19)
                let records: [[String: Any]] = [["b": blob], ["b": ""]]
                let size = (try? JSONSerialization.data(withJSONObject: records))?.count
                expect(size).to(equal(SensorSampleUploadManager.maxBatchBytes))
                expect(storage.enqueueBatch(records, windowStart: windowStart, for: sensor)).to(beTrue())
                expect((storage.peekNextBatch(for: sensor, excluding: [])?.records.first?["b"] as? String)?.count)
                    .to(equal(blob.count))
            }
        }

        describe("migration of a 0.101.16/17 UserDefaults queue") {

            it("migration_of_her_shape_4_01_plus_4_65_MB: two files, key gone, contents equal (limit case 8)") {
                let day1 = windowStart
                let day2 = windowStart.addingTimeInterval(QueueFixture.day)
                let head = QueueFixture.legacyEntry(targetBytes: 4_080_000, day: day1)
                let tail = QueueFixture.legacyEntry(targetBytes: 4_730_000, day: day2)
                let blob = QueueFixture.seedLegacy([head, tail], for: sensor)
                expect(blob.count).to(beGreaterThan(8_000_000))

                let relaunched = relaunch()
                expect(relaunched.pendingBatchCount(for: sensor)).to(equal(2))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())
                expect(QueueFixture.batchIds(root, sensor)).to(equal([head["id"] as? String ?? "", tail["id"] as? String ?? ""]))

                for source in [head, tail] {
                    guard let batch = relaunched.dequeueNextBatch(for: sensor) else { return fail("missing batch") }
                    expect(batch.windowStart.timeIntervalSince1970).to(equal(source["window_start"] as? Double))
                    let records = source["records"] as? [[String: Any]] ?? []
                    expect((batch.records as NSArray).isEqual(to: records)).to(beTrue())
                }
                let event = migratedEvents().last
                expect(event?.outcome).to(equal("ok"))
                expect(event?.count).to(equal(2))
                expect(event?.bytes).to(equal(blob.count))
            }

            it("migration_of_empty_array_removes_the_key (limit case 7)") {
                QueueFixture.seedLegacy([], for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
            }

            it("migration_drops_pre_3945_entries_with_telemetry (limit case 10)") {
                // A bare array of records (pre-FUAM-3945) next to a current entry.
                let current: [String: Any] = ["id": "keep", "window_start": windowStart.timeIntervalSince1970,
                                              "records": marked("kept")]
                QueueFixture.seedLegacy([[["t": "2025-01-01T00:00:00Z"], ["t": "2025-01-02T00:00:00Z"]], current], for: sensor)

                expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
                expect(headMarker(storage)).to(equal("kept"))
                expect(droppedReasons()).to(equal(["legacy_queue_entry"]))
                let dropped = analytics.trackedEvents.compactMap { event -> Int? in
                    if case let .sensorRecordDropped(_, count, _) = event { return count }
                    return nil
                }
                expect(dropped).to(equal([2]))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())
            }

            it("idless_entry_ids_are_content_hashes_stable_across_reordering (limit case 9, R2 PR-18)") {
                let first: [String: Any] = ["window_start": windowStart.timeIntervalSince1970, "records": marked("one")]
                let second: [String: Any] = ["window_start": windowStart.timeIntervalSince1970, "records": marked("two")]

                QueueFixture.seedLegacy([first, second], for: sensor)
                _ = storage.pendingBatchCount(for: sensor)
                let ids = QueueFixture.batchIds(root, sensor)
                expect(ids.count).to(equal(2))
                expect(ids.allSatisfy { $0.hasPrefix("legacy-") && $0.count == "legacy-".count + 16 }).to(beTrue())

                let otherRoot = QueueFixture.makeRoot()
                defer { QueueFixture.removeRoot(otherRoot) }
                QueueFixture.seedLegacy([second, first], for: sensor)
                _ = DefaultsSensorStorage(queueDirectory: otherRoot).pendingBatchCount(for: sensor)
                expect(Set(QueueFixture.batchIds(otherRoot, sensor))).to(equal(Set(ids)))
            }

            it("migration_interrupted_after_k_files_completes_without_duplicates (limit case 13)") {
                let entries: [[String: Any]] = [
                    ["id": "e1", "window_start": windowStart.timeIntervalSince1970, "records": marked("1")],
                    ["window_start": windowStart.timeIntervalSince1970, "records": marked("2")], // id-less
                    ["id": "e3", "window_start": windowStart.timeIntervalSince1970, "records": marked("3")]
                ]
                // A complete run elsewhere tells which files the interrupted run had written.
                let referenceRoot = QueueFixture.makeRoot()
                defer { QueueFixture.removeRoot(referenceRoot) }
                QueueFixture.seedLegacy(entries, for: sensor)
                _ = DefaultsSensorStorage(queueDirectory: referenceRoot).pendingBatchCount(for: sensor)
                let referenceFiles = QueueFixture.batchFiles(referenceRoot, sensor)
                expect(referenceFiles.count).to(equal(3))

                // The interrupted run: the first two files written, no marker, the key still there.
                let directory = QueueFixture.sensorDirectory(root, sensor)
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for name in referenceFiles.prefix(2) {
                    try? FileManager.default.copyItem(at: QueueFixture.sensorDirectory(referenceRoot, sensor).appendingPathComponent(name),
                                                      to: directory.appendingPathComponent(name))
                }
                QueueFixture.seedLegacy(entries, for: sensor)

                let resumed = relaunch()
                expect(resumed.pendingBatchCount(for: sensor)).to(equal(3))
                let ids = QueueFixture.batchIds(root, sensor)
                expect(ids.count).to(equal(Set(ids).count))
                expect(Set(ids)).to(equal(Set(QueueFixture.batchIds(referenceRoot, sensor))))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())
                expect(QueueFixture.marker(root, sensor)?.ids).to(equal(Set(ids)))
                var order: [String] = []
                while let batch = resumed.dequeueNextBatch(for: sensor) {
                    order.append(batch.records.first?["marker"] as? String ?? "?")
                }
                expect(order).to(equal(["1", "2", "3"]))
            }

            it("migration_quarantines_unparseable_blob_and_removes_key (limit case 11)") {
                let blob = Data("[{\"id\": \"cut-off".utf8)
                UserDefaults.standard.set(blob, forKey: QueueFixture.legacyKey(sensor))

                expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())
                let quarantined = QueueFixture.quarantined(root)
                expect(quarantined.count).to(equal(1))
                expect(quarantined.first?.hasSuffix("_legacy_unparseable.json")).to(beTrue())
                let kept = quarantined.first.flatMap {
                    try? Data(contentsOf: root.appendingPathComponent("_quarantine").appendingPathComponent($0))
                }
                expect(kept).to(equal(blob))
                expect(migratedEvents().last?.outcome).to(equal("unparseable"))
                expect(QueueFixture.marker(root, sensor)?.digests).to(equal([DefaultsSensorStorage.sha256Hex(blob)]))
            }

            it("drain_is_blocked_until_the_sensor_is_migrated (limit case 14)") {
                // A batch already on disk, and a legacy key the migration cannot write out.
                storage.enqueueBatch(marked("on-disk"), windowStart: windowStart, for: sensor)
                QueueFixture.seedLegacy([["id": "legacy-entry", "window_start": windowStart.timeIntervalSince1970,
                                          "records": marked("legacy")]], for: sensor)
                let directory = QueueFixture.sensorDirectory(root, sensor)
                try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)

                let blocked = relaunch()
                expect(blocked.peekNextBatch(for: sensor, excluding: [])).to(beNil())
                expect(blocked.pendingBatchCount(for: sensor)).to(equal(0))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).toNot(beNil())
                expect(migratedEvents().last?.outcome).to(equal("partial_disk_error"))

                // The next launch, with the disk writable again, completes it.
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
                let resumed = relaunch()
                expect(resumed.pendingBatchCount(for: sensor)).to(equal(2))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())
            }

            it("migration_does_nothing_when_defaults_are_unreadable (limit case 15)") {
                // Before the first unlock a `UserDefaults` read returns nil: no key.
                expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
                expect(QueueFixture.marker(root, sensor)).to(beNil())
                expect(migratedEvents()).to(beEmpty())

                // A later launch reads the key and migrates it.
                QueueFixture.seedLegacy([["id": "later", "window_start": windowStart.timeIntervalSince1970,
                                          "records": marked("later")]], for: sensor)
                expect(headMarker(relaunch())).to(equal("later"))
            }

            it("migration_marker_wins_over_a_resurrected_key (limit case 39)") {
                let blob = QueueFixture.seedLegacy([["id": "m1", "window_start": windowStart.timeIntervalSince1970,
                                                     "records": marked("m1")]], for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
                storage.removeBatch(id: "m1", for: sensor) // uploaded
                // The key removal did not persist.
                UserDefaults.standard.set(blob, forKey: QueueFixture.legacyKey(sensor))
                analytics.reset()

                let relaunched = relaunch()
                expect(relaunched.pendingBatchCount(for: sensor)).to(equal(0))
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())
                expect(migratedEvents()).to(beEmpty()) // recognised by digest, never parsed
            }

            it("downgrade_appended_entries_are_migrated_and_old_ones_skipped (limit case 40)") {
                let first: [String: Any] = ["id": "d1", "window_start": windowStart.timeIntervalSince1970, "records": marked("d1")]
                let second: [String: Any] = ["id": "d2", "window_start": windowStart.timeIntervalSince1970, "records": marked("d2")]
                let third: [String: Any] = ["id": "d3", "window_start": windowStart.timeIntervalSince1970, "records": marked("d3")]
                QueueFixture.seedLegacy([first, second], for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(2))
                storage.removeBatch(id: "d1", for: sensor)
                storage.removeBatch(id: "d2", for: sensor)

                // A downgraded build re-wrote the key (its removal lost) and appended a batch.
                QueueFixture.seedLegacy([first, second, third], for: sensor)
                let relaunched = relaunch()
                expect(relaunched.pendingBatchCount(for: sensor)).to(equal(1))
                expect(QueueFixture.batchIds(root, sensor)).to(equal(["d3"]))
                expect(QueueFixture.marker(root, sensor)?.ids).to(equal(["d1", "d2", "d3"]))
            }

            it("treats a missing marker with the key present as not migrated (limit case 41)") {
                QueueFixture.seedLegacy([["id": "n1", "window_start": windowStart.timeIntervalSince1970,
                                          "records": marked("n1")]], for: sensor)
                expect(QueueFixture.marker(root, sensor)).to(beNil())
                expect(headMarker(storage)).to(equal("n1"))
                expect(QueueFixture.marker(root, sensor)?.ids).to(equal(["n1"]))
            }
        }

        describe("purge support") {

            it("visits file and legacy batches without removing them") {
                storage.enqueueBatch(marked("file"), windowStart: windowStart, for: sensor)
                // A legacy key that a fresh process has not migrated yet.
                let legacyWindow = windowStart.addingTimeInterval(-QueueFixture.day)
                QueueFixture.seedLegacy([["id": "l1", "window_start": legacyWindow.timeIntervalSince1970,
                                          "records": marked("legacy")]], for: sensor)
                var seen: [String] = []
                relaunch().forEachQueuedBatch(for: sensor) { seen.append($0.records.first?["marker"] as? String ?? "?") }
                expect(seen).to(equal(["file", "legacy"]))
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(1))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).toNot(beNil())
            }

            it("purge_keeps_the_migrated_marker, removes files, quarantine and legacy key") {
                QueueFixture.seedLegacy([["id": "k1", "window_start": windowStart.timeIntervalSince1970, "records": marked("k1")]],
                                        for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
                storage.enqueueBatch(marked("x"), windowStart: windowStart, for: sensor)
                guard let headName = QueueFixture.batchFiles(root, sensor).last else { return fail("no file") }
                try? Data("garbage".utf8).write(to: QueueFixture.sensorDirectory(root, sensor).appendingPathComponent(headName))
                storage.removeBatch(id: "k1", for: sensor)
                _ = storage.peekNextBatch(for: sensor, excluding: []) // quarantines the garbage
                expect(QueueFixture.quarantined(root).count).to(equal(1))

                storage.deleteQueue(for: sensor)

                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
                expect(QueueFixture.quarantined(root)).to(beEmpty())
                expect(QueueFixture.marker(root, sensor)?.ids).to(equal(["k1"]))
            }

            it("records a deleted legacy key's digest, so a lost removal cannot resurrect it") {
                let blob = QueueFixture.seedLegacy([["id": "p1", "window_start": windowStart.timeIntervalSince1970,
                                                     "records": marked("p1")]], for: sensor)
                storage.deleteQueue(for: sensor) // never migrated
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).to(beNil())

                UserDefaults.standard.set(blob, forKey: QueueFixture.legacyKey(sensor)) // the removal was lost
                expect(relaunch().pendingBatchCount(for: sensor)).to(equal(0))
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
            }

            it("persists the purge intent marker") {
                expect(storage.isPurgePending).to(beFalse())
                expect(storage.setPurgePending(true)).to(beTrue())
                expect(relaunch().isPurgePending).to(beTrue())
                expect(storage.setPurgePending(false)).to(beTrue())
                expect(relaunch().isPurgePending).to(beFalse())
            }
        }
    }
}

// MARK: - The manager over the file queue

// swiftlint:disable:next type_body_length
class SensorQueueDrainSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour = QueueFixture.hour
        let day = QueueFixture.day
        let sensor = SRSensor.accelerometer
        let device = SensorDevice(device: nil, key: SensorDevice.iphoneKey, productType: "iPhone17,1", systemVersion: "18.0")
        var root: URL!
        var joinDay: Date!
        var storage: DefaultsSensorStorage!
        var analytics: CapturingAnalyticsService!
        var clearance: FakeSensorClearance!
        var network: ConcurrencyRecordingNetwork!

        func makeManager(storage: SensorSampleUploadManagerStorage & SensorSampleUploaderStorage,
                         mapper: SensorSampleMapper = ClosureDeviceMapper { _, _ in [] }) -> SensorSampleUploadManager {
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: analytics,
                                                    mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance
            return manager
        }

        func record(_ marker: String, at offset: TimeInterval = 3600) -> [String: Any] {
            return ["t": QueueFixture.iso(joinDay.addingTimeInterval(offset)), "marker": marker]
        }

        func markers(_ payloads: [[[String: Any]]]) -> [String] {
            return payloads.compactMap { $0.first?["marker"] as? String }
        }

        func backoffs() -> Int {
            return analytics.trackedEvents.filter { event in
                if case .sensorMemoryBackoff = event { return true }
                return false
            }.count
        }

        beforeEach {
            QueueFixture.clearDefaults(sensor)
            root = QueueFixture.makeRoot()
            joinDay = SensorSampleUploadManager.utcDayStart(Date()).addingTimeInterval(-30 * day)
            analytics = CapturingAnalyticsService()
            storage = DefaultsSensorStorage(queueDirectory: root, analytics: analytics)
            clearance = FakeSensorClearance()
            clearance.enrollmentDate = joinDay
            network = ConcurrencyRecordingNetwork()
        }

        afterEach {
            QueueFixture.clearDefaults(sensor)
            QueueFixture.removeRoot(root)
        }

        describe("one upload in flight per sensor") {

            it("one_upload_in_flight_per_sensor_under_ten_concurrent_triggers (limit case 23)") {
                for index in 0..<5 {
                    storage.enqueueBatch([record("b\(index)")], windowStart: joinDay, for: sensor)
                }
                let manager = makeManager(storage: storage)
                manager.setNetworkDelegate(network)

                DispatchQueue.concurrentPerform(iterations: 10) { _ in manager.drainQueue(for: sensor) }

                expect(network.uploaded.count).toEventually(equal(5), timeout: .seconds(10))
                expect(network.maxConcurrent(for: sensor)).to(equal(1))
                expect(markers(network.uploaded)).to(equal(["b0", "b1", "b2", "b3", "b4"]))
                expect(network.attemptCount).toAlways(equal(5), until: .milliseconds(300))
                expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
            }

            it("uploads each batch once when its removal fails after the 200, instead of looping (review A-5)") {
                storage.enqueueBatch([record("a")], windowStart: joinDay, for: sensor)
                storage.enqueueBatch([record("b")], windowStart: joinDay, for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(2))
                let directory = QueueFixture.sensorDirectory(root, sensor)
                try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }
                let manager = makeManager(storage: storage)
                manager.setNetworkDelegate(network)

                manager.drainQueue(for: sensor)

                expect(network.uploaded.count).toEventually(equal(2), timeout: .seconds(5))
                expect(network.attemptCount).toAlways(equal(2), until: .milliseconds(500))
                expect(markers(network.uploaded)).to(equal(["a", "b"]))
            }

            it("a second drain while one runs starts nothing; the running loop ships what was enqueued") {
                storage.enqueueBatch([record("a")], windowStart: joinDay, for: sensor)
                network.delay = 0.3
                let manager = makeManager(storage: storage)
                manager.setNetworkDelegate(network)

                manager.drainQueue(for: sensor)
                expect(network.attemptCount).toEventually(equal(1), timeout: .seconds(5))
                storage.enqueueBatch([record("b")], windowStart: joinDay, for: sensor)
                manager.drainQueue(for: sensor)

                expect(network.uploaded.count).toEventually(equal(2), timeout: .seconds(5))
                expect(markers(network.uploaded)).to(equal(["a", "b"]))
                expect(network.maxConcurrent(for: sensor)).to(equal(1))
            }

            it("transient_failure_requeues_to_tail_and_releases_the_drain (limit case 24)") {
                storage.enqueueBatch([record("a"), record("pre-bound", at: -hour)], windowStart: joinDay.addingTimeInterval(day),
                                     for: sensor)
                storage.enqueueBatch([record("b")], windowStart: joinDay, for: sensor)
                var failedOnce = false
                let lock = NSLock()
                network.errorForPayload = { payload in
                    lock.lock(); defer { lock.unlock() }
                    guard !failedOnce, payload.first?["marker"] as? String == "a" else { return nil }
                    failedOnce = true
                    return RepositoryError.connectivityError
                }
                let manager = makeManager(storage: storage)
                manager.setNetworkDelegate(network)

                manager.drainQueue(for: sensor)
                expect(network.attemptCount).toEventually(equal(1), timeout: .seconds(5))
                // The failed batch is now the tail; the loop has ended and released the sensor.
                expect(storage.peekNextBatch(for: sensor, excluding: [])?.records.first?["marker"] as? String)
                    .toEventually(equal("b"), timeout: .seconds(5))
                manager.drainQueue(for: sensor)

                expect(network.uploaded.count).toEventually(equal(2), timeout: .seconds(5))
                expect(markers(network.uploaded)).to(equal(["b", "a"]))
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(0), timeout: .seconds(5))
            }
        }

        describe("batch size") {

            it("batches_respect_1_MiB: a window of ~3 MiB is split into batches of at most 1 MiB (limit case 3)") {
                let blob = String(repeating: "x", count: 100 * 1024)
                let records: [[String: Any]] = (0..<30).map { index in
                    ["t": QueueFixture.iso(joinDay.addingTimeInterval(TimeInterval(index) * 60)), "i": index, "blob": blob]
                }
                let manager = makeManager(storage: storage)
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))
                let context = SensorSampleUploadManager.DeviceChainContext(sensor: sensor,
                                                                           device: device,
                                                                           devices: [device],
                                                                           deviceIndex: 0,
                                                                           now: Date(),
                                                                           mapper: ClosureDeviceMapper { _, _ in [] },
                                                                           plannedBound: joinDay)

                manager.handleWindowResult(.success(records), window: window, at: 0, of: [window], context: context)

                var sizes: [Int] = []
                var indexes: [Int] = []
                storage.forEachQueuedBatch(for: sensor) { batch in
                    sizes.append((try? JSONSerialization.data(withJSONObject: batch.records))?.count ?? 0)
                    indexes += batch.records.compactMap { $0["i"] as? Int }
                }
                expect(sizes.count).to(beGreaterThan(2))
                expect(sizes.allSatisfy { $0 <= SensorSampleUploadManager.maxBatchBytes }).to(beTrue())
                expect(indexes).to(equal(Array(0..<30)))
            }

            it("allows exactly 1 MiB, bisects one byte more, never splits a single record (limit cases 3, 5)") {
                let cap = SensorSampleUploadManager.maxBatchBytes
                func pair(totalBytes: Int) -> [[String: Any]] {
                    // `[{"b":"<s1>"},{"b":"<s2>"}]` is 19 bytes plus the two strings.
                    return [["b": String(repeating: "x", count: totalBytes - 19)], ["b": ""]]
                }
                let exact = SensorSampleUploadManager.splitRespectingPayloadLimit(pair(totalBytes: cap),
                                                                                  maxBatchSize: 500,
                                                                                  maxBatchBytes: cap)
                expect(exact.map { $0.count }).to(equal([2]))
                let over = SensorSampleUploadManager.splitRespectingPayloadLimit(pair(totalBytes: cap + 1),
                                                                                 maxBatchSize: 500,
                                                                                 maxBatchBytes: cap)
                expect(over.map { $0.count }).to(equal([1, 1]))
                let single = SensorSampleUploadManager.splitRespectingPayloadLimit([["b": String(repeating: "x", count: 2 * cap)]],
                                                                                   maxBatchSize: 500,
                                                                                   maxBatchBytes: cap)
                expect(single.map { $0.count }).to(equal([1]))
            }

            it("splits 501 records into 500 + 1 (limit case 4)") {
                let records: [[String: Any]] = (0..<501).map { ["i": $0] }
                let batches = SensorSampleUploadManager.splitRespectingPayloadLimit(records,
                                                                                    maxBatchSize: 500,
                                                                                    maxBatchBytes: SensorSampleUploadManager.maxBatchBytes)
                expect(batches.map { $0.count }).to(equal([500, 1]))
            }

            it("estimates a record array's JSON size without serializing it (review B-1/B-2)") {
                let small: [[String: Any]] = [["a": 1], ["b": "two"], ["c": [1, 2, 3]], ["d": 0.5, "e": NSNull()]]
                // The value types review B-2 measured low: booleans, fractional and epoch doubles,
                // escaped strings, control characters, multi-byte text, a key needing an escape.
                let awkward: [[String: Any]] = [["flag": true, "off": false, "ratio": 0.1, "third": 1.0 / 3.0,
                                                 "sr_absolute_time": 784_312_345.123, "tiny": 1e-7, "whole": 900.0,
                                                 "big": 123_456_789_012.5, "neg": -0.75],
                                                ["url": "https://example.com/a/b", "quote": "say \"hi\" \\ ok",
                                                 "controls": "\u{08}\u{0C}\n\r\t\u{01}\u{1F}", "text": "é€😀",
                                                 "a/b": "slash key"]]
                let heavy = [QueueFixture.heavyReport(0, at: joinDay), QueueFixture.heavyReport(1, at: joinDay)]
                for records in [small, awkward, heavy] {
                    // Exact on iOS 18.4; 1% leaves room for Foundation changing its float format.
                    let actual = Double((try? JSONSerialization.data(withJSONObject: records))?.count ?? 0)
                    let estimate = Double(SensorSampleUploadManager.estimatedJSONBytes(of: records))
                    expect(estimate).to(beCloseTo(actual, within: actual * 0.01))
                }
                expect(SensorSampleUploadManager.estimatedJSONBytes(of: [])).to(equal(2))
            }

            it("splits a day of 200 KB reports into batches of at most 1 MiB (about 30) and ships each once (R5)") {
                let reports = (0..<96).map { QueueFixture.heavyReport($0, at: joinDay.addingTimeInterval(TimeInterval($0) * 900)) }
                let reportBytes = (try? JSONSerialization.data(withJSONObject: [reports[0]]))?.count ?? 0
                expect(reportBytes).to(beGreaterThan(170_000)) // about 179 KB
                let manager = makeManager(storage: storage)
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))
                let context = SensorSampleUploadManager.DeviceChainContext(sensor: sensor,
                                                                           device: device,
                                                                           devices: [device],
                                                                           deviceIndex: 0,
                                                                           now: Date(),
                                                                           mapper: ClosureDeviceMapper { _, _ in [] },
                                                                           plannedBound: joinDay)

                manager.handleWindowResult(.success(reports), window: window, at: 0, of: [window], context: context)

                var sizes: [Int] = []
                storage.forEachQueuedBatch(for: sensor) { batch in
                    sizes.append((try? JSONSerialization.data(withJSONObject: batch.records))?.count ?? 0)
                }
                expect(sizes.count).to(beGreaterThanOrEqualTo(16))
                expect(sizes.count).to(beLessThanOrEqualTo(32))
                expect(sizes.allSatisfy { $0 <= SensorSampleUploadManager.maxBatchBytes }).to(beTrue())

                manager.setNetworkDelegate(network)
                manager.drainQueue(for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(0), timeout: .seconds(20))
                expect(network.maxConcurrent(for: sensor)).to(equal(1))
                expect(network.attemptCount).to(equal(sizes.count))
                let shipped = network.uploaded.flatMap { $0 }.compactMap { $0["seq"] as? Int }
                expect(shipped).to(equal(Array(0..<96)))
            }

            it("enqueues a single 1.5 MiB record alone and ships it once, never dropped or looped on") {
                let big: [String: Any] = ["t": QueueFixture.iso(joinDay.addingTimeInterval(hour)), "seq": 1,
                                          "blob": String(repeating: "x", count: 3 * 512 * 1024)]
                let records: [[String: Any]] = [["t": QueueFixture.iso(joinDay.addingTimeInterval(60)), "seq": 0], big,
                                                ["t": QueueFixture.iso(joinDay.addingTimeInterval(2 * hour)), "seq": 2]]
                let manager = makeManager(storage: storage)
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))
                let context = SensorSampleUploadManager.DeviceChainContext(sensor: sensor,
                                                                           device: device,
                                                                           devices: [device],
                                                                           deviceIndex: 0,
                                                                           now: Date(),
                                                                           mapper: ClosureDeviceMapper { _, _ in [] },
                                                                           plannedBound: joinDay)

                manager.handleWindowResult(.success(records), window: window, at: 0, of: [window], context: context)

                var batches: [[Int]] = []
                storage.forEachQueuedBatch(for: sensor) { batch in batches.append(batch.records.compactMap { $0["seq"] as? Int }) }
                expect(batches).to(equal([[0], [1], [2]]))
                expect(storage.lastCursor(for: sensor, deviceKey: device.key)).to(equal(window.end))

                manager.setNetworkDelegate(network)
                manager.drainQueue(for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(0), timeout: .seconds(10))
                expect(network.attemptCount).toAlways(equal(3), until: .milliseconds(300))
                expect(network.uploaded.map { $0.compactMap { $0["seq"] as? Int } }).to(equal([[0], [1], [2]]))
            }
        }

        describe("the memory guard") {

            /// A cursor-resume plan of three windows (no probe): the cursor sits three days back.
            func seedForwardCursor(_ fake: FakeSensorStorage) {
                let today = SensorSampleUploadManager.utcDayStart(Date())
                fake.setLastCursor(today.addingTimeInterval(-4 * day), for: sensor)
                fake.setLastRescanDay(today, for: sensor)
            }

            it("memory_guard_skips_the_fetch_without_failure_count (limit case 27)") {
                let fake = FakeSensorStorage()
                seedForwardCursor(fake)
                let cursorBefore = fake.lastCursor(for: sensor)
                let mapper = ClosureDeviceMapper { _, _ in [] }
                let manager = makeManager(storage: fake, mapper: mapper)
                manager.availableMemory = { 100 * 1024 * 1024 }

                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)

                expect(backoffs()).to(equal(1))
                expect(mapper.callCount).to(equal(0))
                expect(fake.lastCursor(for: sensor)).to(equal(cursorBefore))
                expect(manager.windowFetchFailureCount(for: sensor, deviceKey: device.key)).to(equal(0))

                // The chain was released: with memory back, the next cycle fetches.
                manager.availableMemory = { 2 * 1024 * 1024 * 1024 }
                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)
                expect(mapper.callCount).toEventually(beGreaterThan(0), timeout: .seconds(5))
            }

            it("requires 600 MB before a report-sensor fetch and 300 MB for the others (review B-4)") {
                for (guardedSensor, expectBackoff) in [(SRSensor.deviceUsageReport, true), (SRSensor.accelerometer, false)] {
                    analytics.reset()
                    let fake = FakeSensorStorage()
                    let today = SensorSampleUploadManager.utcDayStart(Date())
                    fake.setLastCursor(today.addingTimeInterval(-4 * day), for: guardedSensor)
                    fake.setLastRescanDay(today, for: guardedSensor)
                    let mapper = ClosureDeviceMapper { _, _ in [] }
                    let manager = SensorSampleUploadManager(withSensors: [guardedSensor],
                                                            storage: fake,
                                                            reachability: FakeSensorReachability(),
                                                            analytics: analytics,
                                                            mappers: [guardedSensor: mapper])
                    manager.clearanceDelegate = clearance
                    manager.availableMemory = { 400 * 1024 * 1024 }

                    manager.runDeviceChain(at: 0, of: [device], for: guardedSensor, now: Date(), using: mapper)

                    if expectBackoff {
                        expect(backoffs()).to(equal(1))
                        expect(mapper.callCount).to(equal(0))
                    } else {
                        expect(mapper.callCount).toEventually(beGreaterThan(0), timeout: .seconds(5))
                        expect(backoffs()).to(equal(0))
                    }
                }
                expect(SensorSampleUploadManager.memoryGuardBytes(for: .keyboardMetrics)).to(equal(600 * 1024 * 1024))
                expect(SensorSampleUploadManager.memoryGuardBytes(for: .pedometerData)).to(equal(300 * 1024 * 1024))
            }

            it("treats an unknown available memory (0) as proceed (limit case 28)") {
                let fake = FakeSensorStorage()
                seedForwardCursor(fake)
                let mapper = ClosureDeviceMapper { _, _ in [] }
                let manager = makeManager(storage: fake, mapper: mapper)
                manager.availableMemory = { 0 }

                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)

                expect(mapper.callCount).toEventually(beGreaterThan(0), timeout: .seconds(5))
                expect(backoffs()).to(equal(0))
            }

            it("memory_guard_in_probe_flushes_the_buffer_before_ending_the_chain (limit case 42)") {
                let fake = FakeSensorStorage() // no cursor: a backfill probe from the join day
                let mapper = ClosureDeviceMapper { from, to in
                    // Data only in the two newest windows, [-3d, -2d) and [-2d, -1d).
                    let today = SensorSampleUploadManager.utcDayStart(Date())
                    guard to > today.addingTimeInterval(-3 * day) else { return [] } // `from` is widened by an epsilon
                    return [["t": QueueFixture.iso(from.addingTimeInterval(hour)), "marker": QueueFixture.iso(from)]]
                }
                let manager = makeManager(storage: fake, mapper: mapper)
                let lock = NSLock()
                var calls = 0
                manager.availableMemory = {
                    lock.lock(); defer { lock.unlock() }
                    calls += 1
                    return calls <= 2 ? 0 : 100 * 1024 * 1024 // low before the third fetch
                }

                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)

                expect(fake.enqueued.count).toEventually(equal(2), timeout: .seconds(5))
                expect(backoffs()).toEventually(equal(1), timeout: .seconds(5))
                _ = manager.windowFetchFailureCount(for: sensor, deviceKey: device.key) // work-queue barrier
                let starts = fake.enqueued.map { $0.windowStart }
                expect(starts).to(equal(starts.sorted()))                  // flushed oldest-first
                expect(fake.ledger(for: sensor).count).to(equal(2))         // committed
                expect(fake.lastCursor(for: sensor)).to(beNil())            // no cursor written

                // Next cycle, memory fine: the flushed days are recognised, nothing re-enqueued,
                // and the probe completes with its terminal cursor.
                manager.availableMemory = { 0 }
                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)
                expect(fake.lastCursor(for: sensor)).toEventually(beGreaterThan(Date().addingTimeInterval(-3 * day)),
                                                                  timeout: .seconds(5))
                expect(fake.enqueued.count).to(equal(2))
            }
        }

        describe("the probe buffer byte budget (R4)") {

            it("probe_buffer_flushes_on_byte_budget_before_count") {
                let fake = FakeSensorStorage()
                let blob = String(repeating: "x", count: 600)
                let mapper = ClosureDeviceMapper { from, to in
                    let today = SensorSampleUploadManager.utcDayStart(Date())
                    guard to > today.addingTimeInterval(-6 * day) else { return [] } // `from` is widened by an epsilon
                    return [["t": QueueFixture.iso(from.addingTimeInterval(hour)), "blob": blob]]
                }
                let manager = makeManager(storage: fake, mapper: mapper)
                manager.availableMemory = { 0 }
                manager.probeBufferMaxBytes = 1_000 // two 600-byte records exceed it

                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)

                expect(fake.lastCursor(for: sensor)).toEventuallyNot(beNil(), timeout: .seconds(5))
                let overflows = analytics.trackedEvents.filter { event in
                    if case let .sensorDataBackfillReach(_, _, boundedBy) = event {
                        return boundedBy == BackfillLowerBound.Origin.probeBufferOverflow.rawValue
                    }
                    return false
                }
                expect(overflows.count).to(equal(1))     // far below the 10,000-record cap
                expect(fake.enqueued.count).to(beGreaterThanOrEqualTo(5))
            }

            it("flushes 200 KB reports on the default 8 MiB budget long before the record cap (R4/R5)") {
                let fake = FakeSensorStorage()
                let mapper = ClosureDeviceMapper { from, to in
                    let today = SensorSampleUploadManager.utcDayStart(Date())
                    guard to > today.addingTimeInterval(-6 * day) else { return [] } // `from` is widened by an epsilon
                    // 20 raw reports (~4 MB) per window.
                    return (0..<20).map { QueueFixture.heavyReport($0, at: from.addingTimeInterval(hour + TimeInterval($0) * 60)) }
                }
                let manager = makeManager(storage: fake, mapper: mapper)
                manager.availableMemory = { 0 }
                expect(manager.probeBufferMaxBytes).to(equal(8 * 1024 * 1024))
                expect(manager.probeBufferMaxRecords).to(equal(10_000))

                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)

                expect(fake.lastCursor(for: sensor)).toEventuallyNot(beNil(), timeout: .seconds(30))
                let overflows = analytics.trackedEvents.filter { event in
                    if case let .sensorDataBackfillReach(_, _, boundedBy) = event {
                        return boundedBy == BackfillLowerBound.Origin.probeBufferOverflow.rawValue
                    }
                    return false
                }
                // 60 records (3 windows, about 11 MB) trip the byte budget; the record cap is 10,000.
                expect(overflows.count).to(equal(1))
                expect(fake.enqueued.flatMap { $0.records }.count).to(equal(100))
                expect(fake.enqueued.allSatisfy {
                    ((try? JSONSerialization.data(withJSONObject: $0.records))?.count ?? 0) <= SensorSampleUploadManager.maxBatchBytes
                }).to(beTrue())
            }

            it("ledger retention covers a probe 8 days deep (R3 RR-4)") {
                let fake = FakeSensorStorage()
                let mapper = ClosureDeviceMapper { from, to in
                    let today = SensorSampleUploadManager.utcDayStart(Date())
                    guard to > today.addingTimeInterval(-8 * day) else { return [] } // `from` is widened by an epsilon
                    return [["t": QueueFixture.iso(from.addingTimeInterval(hour))]]
                }
                let manager = makeManager(storage: fake, mapper: mapper)
                manager.availableMemory = { 0 }

                manager.runDeviceChain(at: 0, of: [device], for: sensor, now: Date(), using: mapper)

                expect(fake.lastCursor(for: sensor)).toEventuallyNot(beNil(), timeout: .seconds(5))
                let today = SensorSampleUploadManager.utcDayStart(Date())
                let days = Set(fake.ledger(for: sensor).values.map { $0.day })
                expect(days).to(contain(today.addingTimeInterval(-8 * day)))
                expect(SensorSampleUploadManager.ledgerRetentionDays).to(equal(9))
            }
        }

        describe("protected data unavailable, before the first unlock (review A-2)") {

            it("no_purge_while_protected_data_is_unavailable") {
                storage.enqueueBatch([record("queued")], windowStart: joinDay, for: sensor)
                let cursor = joinDay.addingTimeInterval(20 * day)
                storage.setLastCursor(cursor, for: sensor, deviceKey: SensorDevice.iphoneKey)
                let manager = makeManager(storage: storage)
                manager.isProtectedDataAvailable = { false }
                // Before the first unlock the token reads as absent, so clearance reads as false.
                clearance.sensorManagerCanRun = false

                manager.startUploadLogic()
                manager.triggerSync(reason: "spec")
                manager.drainQueue(for: sensor)

                expect(storage.isPurgePending).toAlways(beFalse(), until: .milliseconds(400))
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(1))
                expect(storage.lastCursor(for: sensor, deviceKey: SensorDevice.iphoneKey)).to(equal(cursor))
            }

            it("sync_resumes_normally_after_protected_data_becomes_available") {
                storage.enqueueBatch([record("queued")], windowStart: joinDay, for: sensor)
                let lock = NSLock()
                var available = false
                let manager = makeManager(storage: storage)
                manager.isProtectedDataAvailable = {
                    lock.lock(); defer { lock.unlock() }
                    return available
                }
                manager.setNetworkDelegate(network)

                manager.startUploadLogic() // deferred
                manager.drainQueue(for: sensor)
                expect(network.attemptCount).toAlways(equal(0), until: .milliseconds(300))
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(1))

                lock.lock(); available = true; lock.unlock()
                manager.protectedDataBecameAvailable() // what the UIKit notification calls

                expect(network.uploaded.count).toEventually(equal(1), timeout: .seconds(5))
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(0), timeout: .seconds(5))
            }

            it("purges once protected data is available if clearance is really gone") {
                storage.enqueueBatch([record("queued")], windowStart: joinDay, for: sensor)
                let lock = NSLock()
                var available = false
                let manager = makeManager(storage: storage)
                manager.isProtectedDataAvailable = {
                    lock.lock(); defer { lock.unlock() }
                    return available
                }
                clearance.sensorManagerCanRun = false
                manager.startUploadLogic()
                expect(QueueFixture.batchFiles(root, sensor).count).toAlways(equal(1), until: .milliseconds(300))

                lock.lock(); available = true; lock.unlock()
                manager.protectedDataBecameAvailable()

                expect(QueueFixture.batchFiles(root, sensor)).toEventually(beEmpty(), timeout: .seconds(5))
            }
        }

        describe("the kill-safe purge (R2 PR-7)") {

            func batchRecords(_ marker: String, deviceKind: String = SensorDevice.iphoneKey) -> [[String: Any]] {
                return [["t": QueueFixture.iso(joinDay.addingTimeInterval(10 * day)), "marker": marker, "device_kind": deviceKind]]
            }

            it("purge_rewinds_cursors_before_deleting_files (limit case 29)") {
                let windowStart = joinDay.addingTimeInterval(10 * day)
                storage.enqueueBatch(batchRecords("old"), windowStart: windowStart, for: sensor)
                storage.setLastCursor(joinDay.addingTimeInterval(20 * day), for: sensor, deviceKey: SensorDevice.iphoneKey)
                let recording = OrderRecordingStorage(base: storage)
                let manager = makeManager(storage: recording)
                clearance.sensorManagerCanRun = false

                manager.triggerSync(reason: "spec")

                expect(recording.calls).toEventually(contain("setPurgePending(false)"), timeout: .seconds(5))
                let calls = recording.calls
                let order = ["setPurgePending(true)", "forEachQueuedBatch", "setLastCursor", "purgeLedger", "deleteQueue",
                             "setPurgePending(false)"]
                expect(order.compactMap { calls.firstIndex(of: $0) }).to(equal(order.compactMap { calls.firstIndex(of: $0) }.sorted()))
                expect(order.allSatisfy { calls.contains($0) }).to(beTrue())
                expect(storage.lastCursor(for: sensor, deviceKey: SensorDevice.iphoneKey)).to(equal(windowStart))
                expect(QueueFixture.batchFiles(root, SRSensor.accelerometer)).to(beEmpty())
                expect(storage.isPurgePending).to(beFalse())
            }

            it("keeps the purge marker when a deletion fails, and uploads nothing until the purge completes (review A-3)") {
                storage.enqueueBatch([record("old-user")], windowStart: joinDay, for: sensor)
                let directory = QueueFixture.sensorDirectory(root, sensor)
                try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }
                let manager = makeManager(storage: storage)
                manager.setNetworkDelegate(network)
                clearance.sensorManagerCanRun = false

                manager.triggerSync(reason: "spec") // the purge runs; its deletion fails

                expect(storage.isPurgePending).toEventually(beTrue(), timeout: .seconds(5))
                _ = manager.windowFetchFailureCount(for: sensor, deviceKey: device.key) // work-queue barrier
                expect(storage.isPurgePending).to(beTrue())
                expect(QueueFixture.batchFiles(root, sensor).count).to(equal(1))

                // A new session: clearance is back, but the leftover must not upload.
                clearance.sensorManagerCanRun = true
                manager.drainQueue(for: sensor)
                expect(network.attemptCount).toAlways(equal(0), until: .milliseconds(300))

                // The disk recovers: the next drain completes the purge, still uploading nothing.
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
                manager.drainQueue(for: sensor)
                expect(storage.isPurgePending).toEventually(beFalse(), timeout: .seconds(5))
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
                expect(network.attemptCount).toAlways(equal(0), until: .milliseconds(300))
            }

            it("purge_interrupted_then_new_login_uploads_nothing_of_the_old_user (limit case 44)") {
                storage.enqueueBatch([record("old-user")], windowStart: joinDay, for: sensor)
                storage.setPurgePending(true) // killed mid-purge
                let relaunched = DefaultsSensorStorage(queueDirectory: root, analytics: analytics)
                let manager = makeManager(storage: relaunched)
                manager.setNetworkDelegate(network) // clearance is back (new login)

                manager.drainQueue(for: sensor)

                expect(relaunched.isPurgePending).toEventually(beFalse(), timeout: .seconds(5))
                expect(QueueFixture.batchFiles(root, sensor)).to(beEmpty())
                expect(network.attemptCount).toAlways(equal(0), until: .milliseconds(300))
            }

            it("purge_removes_the_legacy_key_of_an_unmigrated_sensor and rewinds to its window (limit case 45)") {
                let legacyWindow = joinDay.addingTimeInterval(5 * day)
                QueueFixture.seedLegacy([["id": "legacy-1", "window_start": legacyWindow.timeIntervalSince1970,
                                          "records": batchRecords("legacy")]], for: sensor)
                let fresh = DefaultsSensorStorage(queueDirectory: root, analytics: analytics)
                fresh.setLastCursor(joinDay.addingTimeInterval(20 * day), for: sensor, deviceKey: SensorDevice.iphoneKey)
                let manager = makeManager(storage: fresh)
                clearance.sensorManagerCanRun = false

                manager.triggerSync(reason: "spec")

                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).toEventually(beNil(), timeout: .seconds(5))
                expect(fresh.lastCursor(for: sensor, deviceKey: SensorDevice.iphoneKey)).toEventually(equal(legacyWindow),
                                                                                                      timeout: .seconds(5))
                // Nothing migrates later.
                expect(DefaultsSensorStorage(queueDirectory: root).pendingBatchCount(for: sensor)).to(equal(0))
            }

            it("deletes a marker-listed legacy key without rewinding the cursor (R3 RR-5)") {
                let blob = QueueFixture.seedLegacy([["id": "done-1", "window_start": joinDay.timeIntervalSince1970,
                                                     "records": batchRecords("done")]], for: sensor)
                expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
                storage.removeBatch(id: "done-1", for: sensor) // uploaded
                UserDefaults.standard.set(blob, forKey: QueueFixture.legacyKey(sensor)) // removal lost
                let cursor = joinDay.addingTimeInterval(20 * day)
                storage.setLastCursor(cursor, for: sensor, deviceKey: SensorDevice.iphoneKey)
                let manager = makeManager(storage: DefaultsSensorStorage(queueDirectory: root, analytics: analytics))
                clearance.sensorManagerCanRun = false

                manager.triggerSync(reason: "spec")

                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).toEventually(beNil(), timeout: .seconds(5))
                expect(storage.lastCursor(for: sensor, deviceKey: SensorDevice.iphoneKey)).to(equal(cursor))
            }

            it("key_removal_lost_after_drain_does_not_reupload (limit case 39)") {
                let blob = QueueFixture.seedLegacy([["id": "up-1", "window_start": joinDay.timeIntervalSince1970,
                                                     "records": [record("legacy")]]], for: sensor)
                let manager = makeManager(storage: storage)
                manager.setNetworkDelegate(network)
                manager.drainQueue(for: sensor)
                expect(network.uploaded.count).toEventually(equal(1), timeout: .seconds(5))
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(0), timeout: .seconds(5))

                UserDefaults.standard.set(blob, forKey: QueueFixture.legacyKey(sensor)) // the removal did not persist
                let relaunchedNetwork = ConcurrencyRecordingNetwork()
                let relaunched = makeManager(storage: DefaultsSensorStorage(queueDirectory: root, analytics: analytics))
                relaunched.setNetworkDelegate(relaunchedNetwork)
                relaunched.drainQueue(for: sensor)

                expect(relaunchedNetwork.attemptCount).toAlways(equal(0), until: .milliseconds(400))
                expect(UserDefaults.standard.data(forKey: QueueFixture.legacyKey(sensor))).toEventually(beNil(), timeout: .seconds(5))
            }
        }
    }
}
