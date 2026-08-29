//
//  HealthSampleUploadManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/06/21.
//

import Foundation
import RxSwift

protocol HealthSampleUploadManagerClearanceDelegate: AnyObject {
    var healthManagerCanRun: Bool { get }

    /// The participant's **study join day** — start of day in the participant's timezone,
    /// derived from the backend's `days_in_study` (FUAM-3841, FUAM-3945). Feeds
    /// `BackfillLowerBound`, which is the lower bound of the HealthKit backfill and the hard
    /// consent gate for sample measurement timestamps. `nil` when it cannot be established
    /// (no user, or `days_in_study <= 0`), which means forward-only collection.
    var enrollmentDate: Date? { get }

    /// The participant's BACKEND-authoritative timezone (`user.time_zone`) — the calendar the
    /// historical chunk boundaries are computed in (FUAM-3945 AC2 revised). `nil` when no user
    /// record is loaded; the caller falls back to UTC (never to `TimeZone.current`).
    var participantTimeZone: TimeZone? { get }
}

protocol HealthSampleUploadManagerReachability {
    var isCurrentlyReachableForHealthSampleUpload: Bool { get }
    func getIsReachableForHealthSampleUploadObserver() -> Observable<Bool>
}

protocol HealthSampleUploadManagerStorage {
    /// Per-data-type upload cursor (review fix #4 — a single shared start date meant only the
    /// first uploader ever backfilled; every subsequent type got a seconds-wide window).
    /// Implementations fall back to the legacy shared key when no per-type value exists yet,
    /// so existing installs resume instead of re-uploading from scratch.
    func uploadStartDate(forDataType dataType: HealthDataType) -> Date?
    func setUploadStartDate(_ date: Date?, forDataType dataType: HealthDataType)
    var lastUploadSequenceCompletionDate: Date? { get set }
    var lastUploadSequenceStartingDate: Date? { get set }
    var pendingUploadDataType: HealthDataType? { get set }
}

#if HEALTHKIT
import HealthKit

class HealthSampleUploadManager {
    
    private var storage: HealthSampleUploadManagerStorage
    weak var clearanceDelegate: HealthSampleUploadManagerClearanceDelegate?

    /// FUAM-3844: returns `true` while the HealthKit authorization prompt has not been requested yet
    /// (`HKAuthorizationRequestStatus.shouldRequest`). Set by `HealthManager` right after init.
    /// Unauthorized anchored queries succeed with zero samples, so running the sequence before the
    /// prompt would permanently advance `uploadStartDate` past data the participant grants later.
    var isStillShouldRequestCheck: () -> Single<Bool> = { Single.just(false) }
    
    private var uploadSequenceScheduledOrRunning: Bool = false

    /// `<data type>|<origin>` pairs already reported this launch (telemetry noise guard): these
    /// conditions repeat on every hourly sequence and a muted event is a useless event.
    private var reportedOnce: Set<String> = []

    private let reachability: HealthSampleUploadManagerReachability
    private let analytics: AnalyticsService
    /// Internal (not private) so the specs can drive `startUpload(forUploader:)` directly.
    let uploaders: [HealthSampleUploader]
    private let disposeBag = DisposeBag()

    init(withDataTypes dataTypes: [HealthDataType],
         storage: HealthSampleUploadManagerStorage & HealthSampleUploaderStorage,
         reachability: HealthSampleUploadManagerReachability,
         analytics: AnalyticsService) {
        self.storage = storage
        self.reachability = reachability
        self.analytics = analytics
        let sampleTypes = dataTypes
            .filter { $0.sampleType != nil }
            .filter { $0.isValid }
        self.uploaders = sampleTypes.map { HealthSampleUploader(withSampleDataType: $0, storage: storage) }
        self.logDebugText(text: "Initialized with \(self.uploaders.count) uploaders")
        // FUAM-3841: per-data-type upload start dates are initialized lazily in
        // `startUpload(forUploader:)`, once clearance (hence the enrollment date) is available.
    }
    
    /// How one time chunk is fetched and uploaded. Production value forwards straight to
    /// `HealthSampleUploader.run`; the specs substitute it, because a simulator's HealthKit store
    /// cannot be seeded and the payload-size paths would otherwise be unreachable from here.
    var uploadChunk: (HealthSampleUploader, DateInterval, Date, Bool) -> Single<()> = { uploader, chunk, minimum, anchored in
        return uploader.run(startDate: chunk.start,
                            endDate: chunk.end,
                            source: "health_kit",
                            minimumSampleDate: minimum,
                            useAnchoredQuery: anchored)
    }

    public func setNetworkDelegate(_ networkDelegate: HealthSampleUploaderNetworkDelegate) {
        self.uploaders.forEach { $0.networkDelegate = networkDelegate }
    }
    
    public func startUploadLogic() {
        guard self.uploaders.count > 0 else {
            self.logDebugText(text: "Upload flow not started. No sample types to process")
            return
        }
        self.logDebugText(text: "Upload logic started")
        
        // This subscription must happen after the first call to scheduleUploadSequence
        self.reachability.getIsReachableForHealthSampleUploadObserver()
            .subscribe(onNext: { [weak self] reachable in
                guard let self = self else { return }
                if reachable, self.uploadSequenceScheduledOrRunning == false {
                    self.scheduleUploadSequence()
                }
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: - Private Methods
    
    private func scheduleUploadSequence() {
        guard self.uploadSequenceScheduledOrRunning == false else {
            assertionFailure("Trying to schedule an upload sequence while one is already scheduled or running")
            return
        }
        self.uploadSequenceScheduledOrRunning = true
        
        let dueTimeSeconds: Int
        if let lastUploadSequenceCompletionDate = self.storage.lastUploadSequenceCompletionDate {
            let nextUploadSequenceDate = lastUploadSequenceCompletionDate.addingTimeInterval(Constants.HealthKit.UploadSequenceTimeInterval)
            dueTimeSeconds = max(0, Int(nextUploadSequenceDate.timeIntervalSinceNow))
        } else {
            dueTimeSeconds = 0
        }
        
        Observable<Int>
            .timer(.seconds(dueTimeSeconds), scheduler: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.startUploadSequence()
            }).disposed(by: self.disposeBag)
    }
    
    private func startUploadSequence() {
        guard let clearanceDelegate = self.clearanceDelegate else {
            assertionFailure("Missing Clearance Delegate")
            return
        }
        guard clearanceDelegate.healthManagerCanRun else {
            self.deferUploadSequence(reason: "Upload sequence has no clearance")
            return
        }

        // FUAM-3844: never run (nor advance uploadStartDate) before the authorization prompt
        // has actually been shown, otherwise the pre-grant window is silently skipped.
        self.isStillShouldRequestCheck()
            .catchAndReturn(true) // on error, defer rather than risk burning the cursor
            .subscribe(onSuccess: { [weak self] stillShouldRequest in
                guard let self = self else { return }
                if stillShouldRequest {
                    self.deferUploadSequence(reason: "Upload sequence deferred: HealthKit authorization not requested yet")
                } else {
                    self.runUploadSequence()
                }
            }).disposed(by: self.disposeBag)
    }

    private func deferUploadSequence(reason: String) {
        self.logDebugText(text: reason)
        self.storage.lastUploadSequenceCompletionDate = Date()
        self.uploadSequenceScheduledOrRunning = false
        self.scheduleUploadSequence()
    }

    private func runUploadSequence() {
        self.logDebugText(text: "Upload sequence started")

        // If too much time has passed from the sequence start and, in that case, restart from the beginning (drop the pending upload)
        if let lastUploadSequenceStartingDate = self.storage.lastUploadSequenceStartingDate,
           lastUploadSequenceStartingDate.addingTimeInterval(Constants.HealthKit.PendingUploadExpireTimeInterval) < Date() {
            self.storage.pendingUploadDataType = nil
        }
        
        self.storage.lastUploadSequenceStartingDate = Date()
        
        if let pendingUploader = self.getPendingUploader() {
            self.logDebugText(text: "Resuming pending uploader")
            self.startUpload(forUploader: pendingUploader)
        } else if let firstUploader = self.uploaders.first {
            self.logDebugText(text: "Start from first uploader")
            self.startUpload(forUploader: firstUploader)
        } else {
            self.logDebugText(text: "No sample data types to be uploaded")
        }
    }
    
    func startUpload(forUploader uploader: HealthSampleUploader) {
        self.storage.pendingUploadDataType = uploader.sampleDataType

        guard self.reachability.isCurrentlyReachableForHealthSampleUpload else {
            self.logDebugText(text: "Upload sequence stopped due to not available connection")
            self.uploadSequenceScheduledOrRunning = false
            return
        }

        let dataType = uploader.sampleDataType

        // FUAM-3945: the shared backfill bound — the study join day, floored at 365 days, and
        // forward-only when the join day cannot be established. Identical policy to SensorKit.
        // FUAM-3964 (review I1): resolved against `max(deviceNow, serverNow)`. The 365-day floor
        // is `now - 365d`, so a device clock rolled BACK by Δ would push the floor back with it
        // and let the walk reach 365 + Δ real days. `max` is the safe direction for a lower
        // bound — the later of the two clocks can only tighten it. (The upper bound below takes
        // `min` for the mirror-image reason.)
        let bound = BackfillLowerBound.resolve(joinDay: self.clearanceDelegate?.enrollmentDate,
                                               now: max(Date(), ServerClock.now()))
        // F8: one breadcrumb per launch when the cap has never had anything to cap with.
        ServerClock.reportMissingOffsetOnce(analytics: self.analytics)

        // FUAM-3841: per-data-type cursor (review fix #4). When no cursor exists yet (fresh
        // install; legacy shared key covered by the storage fallback) backfill from the bound —
        // HealthKit has no OS retention limit, so the bound is the only limit. `healthQuery`
        // also applies the hard consent gate: the walk never starts below the bound, even if a
        // stale stored cursor predates it.
        let storedStartDate = self.storage.uploadStartDate(forDataType: dataType)
        guard let query = bound.healthQuery(storedCursor: storedStartDate) else {
            // No join day ⇒ no history may be collected, for any host, with or without the
            // consent-bypass flags. The cursor is deliberately left untouched (unlike the
            // FUAM-3841 bypass path, which burned it to `now`): once the join day resolves,
            // the real backfill still runs. Nothing is uploaded for this data type meanwhile.
            self.reportForwardOnlyOnce(forDataType: dataType, bound: bound)
            self.processNextUploader(forUploader: uploader)
            return
        }

        let minimumSampleDate = query.minimumSampleDate
        var startDate = query.startDate

        // FUAM-3964: the walk plans (and persists a cursor) up to here, so it is capped at server
        // time. A device clock years ahead would otherwise burn the cursor years into the future,
        // and correcting the clock would then leave the walk with nothing to do until real time
        // caught up. The QUERY still runs in device wall-clock — HealthKit indexes its store with
        // the same clock that wrote the samples — only the plan is capped.
        let endDate = min(Date(), ServerClock.now())
        let oneDay: TimeInterval = 24 * 3600

        // FUAM-3964 (F1): a cursor more than a day above the capped end of the walk cannot have
        // been written by a sane clock — only by an offline forward clock excursion, which runs
        // this pipeline uncapped. Left alone it parks the walk until real time passes it and then
        // resumes AT it, so the interval in between is silently never fetched. Reset it to the
        // consent bound and re-walk; `BackfillLowerBound.isFutureBurned` documents why this one
        // rewind is safe. Reported with the corrupt cursor as the reach, so the recovered gap is
        // readable. The reset is its own once-per-launch guard: the next sequence cannot re-detect.
        if BackfillLowerBound.isFutureBurned(cursor: storedStartDate, upperBound: endDate) {
            self.logDebugText(text: "Cursor for \(dataType.keyName) was burnt into the future "
                              + "(\(String(describing: storedStartDate))); reset to \(bound.date)")
            self.report(dataType: dataType,
                        date: storedStartDate ?? bound.date,
                        origin: .futureCursor)
            startDate = bound.date
            self.storage.setUploadStartDate(startDate, forDataType: dataType)
        } else {
            // FUAM-3945 (F9): the reach was previously only reported on a FIRST-EVER walk
            // (`storedStartDate == nil`), i.e. never for the entire upgrade cohort. Mirror
            // SensorKit: report whenever a real backfill decision was taken — a cursor at or
            // below the bound was clamped to it, which is a backfill — and stay silent on a
            // routine cursor resume. Once per data type per launch.
            let isCursorResume = (storedStartDate.map { $0 > bound.date }) ?? false
            if !isCursorResume {
                self.logDebugText(text: "Backfill lower bound for \(dataType.keyName) set to \(startDate) "
                                  + "(\(bound.origin.rawValue))")
                self.reportOnce(dataType: dataType, date: startDate, origin: bound.origin)
            }
        }
        // Review fixes #7/#8: while the cursor is far behind (historical walk) use coarse
        // day-sized chunks; near the head revert to hour-sized chunks.
        let historicalThreshold: TimeInterval = 7 * oneDay

        // AC2 (revised 2026-08-29): chunk boundaries are a pure function of absolute time —
        // historical chunks end on PARTICIPANT-timezone day boundaries (the backend-authoritative
        // `user.time_zone`, the same authority the adherence chart buckets rows with), head
        // chunks on epoch-hour boundaries — never a cursor-relative stride. A post-reinstall
        // re-walk therefore partitions the same samples into the same batches and reproduces the
        // same server anchors instead of minting shifted near-duplicate rows.
        let partitionTimeZone = self.clearanceDelegate?.participantTimeZone ?? Self.fallbackPartitionTimeZone

        // FUAM-3945: ends of the sub-windows an oversize chunk was split into, innermost last. A
        // sub-window always STARTS at the cursor, so only its end has to be remembered: the
        // current chunk is [startDate, bisectedEnds.last], and completing it moves the cursor to
        // that end, which pops the entry and turns the next one into the following half.
        // Bisecting by TIME (never by record count) is what keeps a retry reproducible: the same
        // sub-window yields the same server-side semantic anchor (`min(startDate)` over the
        // payload), so a re-upload merges by sample `uuid` instead of scattering new rows.
        var bisectedEnds: [Date] = []
        // Attempts spent on the CURRENT chunk, reset whenever the chunk changes (completed,
        // forfeited or bisected). Also bounds the connectivity retry, which had no bound at all.
        var chunkAttempts = 0

        func processNextChunk() {
            // FUAM-3945 (review round 4, I2): the walk cannot return anything once its start has
            // reached the end of the window, and persisting `nextEndDate` over a window that was
            // never read forfeits it for good. Skip the data type and leave the cursor ALONE, the
            // same contract as the forward-only skip above. Two live cases: a cursor already at
            // the head (nothing to do, nothing lost), and a bound that has not been reached yet —
            // a join day in the future. A cursor burnt into the future no longer reaches this
            // guard: it is detected and reset above (F1), because parking here forfeited the
            // interval between the excursion and the cursor rather than merely delaying it.
            guard startDate < endDate else {
                self.logDebugText(text: "Skipping \(dataType.keyName): start \(startDate) is not before "
                                  + "end \(endDate); cursor left untouched")
                self.processNextUploader(forUploader: uploader)
                return
            }

            let isHistorical = endDate.timeIntervalSince(startDate) > historicalThreshold
            let boundary = isHistorical
                ? Self.nextParticipantDayStart(after: startDate, timeZone: partitionTimeZone)
                : Self.nextEpochHourBoundary(after: startDate)
            let nextEndDate = bisectedEnds.last ?? min(boundary, endDate)

            // Everything up to `date` is uploaded (or deliberately forfeited): persist it — review
            // fix #7, so an interrupted multi-month walk resumes instead of restarting from
            // enrollment — and carry on with the next chunk, or with the next data type.
            //
            // Walk invariant: the ONLY exit condition here is TIME. It must never be gated on the
            // chunk having returned something — Apple's own anchored-query sample code stops on
            // "no added samples && no deleted objects", which truncates a historical walk at its
            // first empty batch (deletions being rare), while an empty chunk in the middle of a
            // backfill is perfectly normal and still has to advance the cursor.
            func advance(past date: Date) {
                self.storage.setUploadStartDate(date, forDataType: dataType)
                if bisectedEnds.last == date {
                    bisectedEnds.removeLast()
                }
                chunkAttempts = 0
                if date < endDate {
                    startDate = date
                    processNextChunk()
                } else {
                    self.processNextUploader(forUploader: uploader)
                }
            }

            chunkAttempts += 1
            guard chunkAttempts <= Constants.HealthKit.MaxChunkUploadAttempts else {
                // Budget spent on ONE chunk: hand the sequence on WITHOUT touching the cursor, so
                // the next sequence retries this very chunk. That costs one cycle and never data,
                // but it has to be visible — FUAM-3835 ran for six weeks on this kind of silence.
                self.logDebugText(text: "Giving up on \(dataType.keyName) chunk \(startDate) -> \(nextEndDate) after "
                                  + "\(chunkAttempts - 1) attempts; cursor left untouched")
                self.reportOnce(dataType: dataType, date: nextEndDate, origin: .attemptsExhausted)
                self.processNextUploader(forUploader: uploader)
                return
            }

            self.uploadChunk(uploader,
                             DateInterval(start: startDate, end: nextEndDate),
                             minimumSampleDate,
                             !isHistorical)
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.logDebugText(text: "Upload from \(startDate) to \(nextEndDate) completed")
                    advance(past: nextEndDate)
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.logDebugText(text: "Upload failed from \(startDate) to \(nextEndDate) with error: \(error)")
                    
                    guard let sampleUploadError = error as? HealthSampleUploaderError else {
                        // F3: an error this switch does not know about used to return here —
                        // without advancing, without clearing `uploadSequenceScheduledOrRunning`
                        // and without rescheduling, i.e. HealthKit stopped for the whole process
                        // lifetime, silently, in Release. Report it (the domain/code is the only
                        // thing that makes it actionable) and hand the sequence on: this data
                        // type loses one cycle, nothing else stalls, and the cursor is untouched
                        // so the chunk is retried next sequence.
                        assertionFailure("Unexpected error type")
                        let nsError = error as NSError
                        self.report(dataType: dataType,
                                    date: nextEndDate,
                                    boundedBy: "\(BackfillLowerBound.Origin.gaveUp.rawValue):\(nsError.domain)#\(nsError.code)")
                        self.processNextUploader(forUploader: uploader)
                        return
                    }
                    
                    switch sampleUploadError {
                    case .internalError, .fetchDataError, .unexpectedDataType, .uploadServerError:
                        self.logDebugText(text: "Upload error: \(sampleUploadError)")
                        self.processNextUploader(forUploader: uploader)
                    case .uploadConnectivityError:
                        self.logDebugText(text: "Upload connectivity error. Retrying current chunk")
                        processNextChunk()  // Retry the upload of this chunk
                    case .uploadPayloadTooLarge:
                        // FUAM-3945: over the server's 10 MB request cap. Halve the chunk's TIME
                        // window and retry each half, in order; the cursor only ever moves to the
                        // end of a half that actually made it.
                        let span = nextEndDate.timeIntervalSince(startDate)
                        guard span > Constants.HealthKit.MinimumChunkDuration else {
                            // Even a floor-sized sub-window is too large. Forfeit it and move
                            // past it: that IS data loss, hence the `gave_up` trace, but the
                            // alternative is retrying the same impossible chunk for ever and
                            // stalling everything behind it in this data type.
                            self.logDebugText(text: "Forfeiting \(dataType.keyName) sub-window \(startDate) -> "
                                              + "\(nextEndDate): still too large at the bisection floor")
                            self.report(dataType: dataType, date: nextEndDate, origin: .gaveUp)
                            advance(past: nextEndDate)
                            return
                        }
                        if bisectedEnds.last != nextEndDate {
                            bisectedEnds.append(nextEndDate)
                        }
                        bisectedEnds.append(startDate.addingTimeInterval(span / 2))
                        chunkAttempts = 0  // each half is a new chunk, with its own budget
                        self.logDebugText(text: "Bisecting oversize \(dataType.keyName) chunk \(startDate) -> \(nextEndDate)")
                        self.reportOnce(dataType: dataType, date: nextEndDate, origin: .bisected)
                        processNextChunk()
                    }
                }).disposed(by: self.disposeBag)
        }

        processNextChunk()  // Start the first chunk
    }

    /// Forward-only means "we could not establish the join day", which is actionable but
    /// permanent until the user record loads — report it at most once per data type per launch
    /// instead of on every hourly sequence.
    private func reportForwardOnlyOnce(forDataType dataType: HealthDataType, bound: BackfillLowerBound) {
        self.logDebugText(text: "Skipping \(dataType.keyName): no study join day, collection is forward-only")
        self.reportOnce(dataType: dataType, date: bound.date, origin: bound.origin)
    }

    /// `sensor_data_backfill_reach`, at most once per data type per origin per launch.
    private func reportOnce(dataType: HealthDataType, date: Date, origin: BackfillLowerBound.Origin) {
        guard self.reportedOnce.insert(dataType.keyName + "|" + origin.rawValue).inserted else { return }
        self.report(dataType: dataType, date: date, origin: origin)
    }

    /// `sensor_data_backfill_reach`, unthrottled: for the events that trace actual data loss.
    private func report(dataType: HealthDataType, date: Date, origin: BackfillLowerBound.Origin) {
        self.report(dataType: dataType, date: date, boundedBy: origin.rawValue)
    }

    /// Same event with a free-form `bounded_by`. Used only by the unrecognised-upload-error path,
    /// which appends the error domain/code to the `gave_up` value (see `AnalyticsEvent`).
    private func report(dataType: HealthDataType, date: Date, boundedBy: String) {
        self.analytics.track(event: .sensorDataBackfillReach(sensor: "health_kit_" + dataType.keyName,
                                                             reachedBack: ISO8601DateFormatter().string(from: date),
                                                             boundedBy: boundedBy))
    }

    private func processNextUploader(forUploader uploader: HealthSampleUploader) {
        self.storage.pendingUploadDataType = nil
        if let nextUploader = self.uploaders.getNextUploader(forDataType: uploader.sampleDataType) {
            self.startUpload(forUploader: nextUploader)
        } else {
            self.logDebugText(text: "Upload sequence completed")
            self.storage.lastUploadSequenceCompletionDate = Date()
            self.uploadSequenceScheduledOrRunning = false
            self.scheduleUploadSequence()
        }
    }
    
    // MARK: - Absolute-time chunk boundaries (FUAM-3945, AC2 revised)

    /// The deterministic fallback when no backend-authoritative `user.time_zone` is available:
    /// UTC, never `TimeZone.current` (which would make the partition travel-dependent).
    static let fallbackPartitionTimeZone = TimeZone(identifier: "UTC")!

    /// The first participant-day boundary STRICTLY after `date` — 23/24/25 real hours away
    /// depending on DST: proper calendar arithmetic, never a fixed 86400 stride.
    static func nextParticipantDayStart(after date: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(24 * 3600)
    }

    /// The first epoch-hour boundary STRICTLY after `date`. Timezone-free by construction, so
    /// the head partition is a pure function of absolute time.
    static func nextEpochHourBoundary(after date: Date) -> Date {
        let hour: TimeInterval = 3600
        return Date(timeIntervalSince1970: ((date.timeIntervalSince1970 / hour).rounded(.down) + 1) * hour)
    }

    private func getPendingUploader() -> HealthSampleUploader? {
        if let pendingUploadDataType = self.storage.pendingUploadDataType {
            return self.uploaders.getUploader(forDataType: pendingUploadDataType)
        } else {
            return nil
        }
    }
    
    private func logDebugText(text: String) {
        #if DEBUG
        if Constants.HealthKit.EnableDebugLog {
            print("HealthSampleUploadManager - \(text)")
        }
        #endif
    }
}

extension Array where Element == HealthSampleUploader {
    func getNextUploader(forDataType dataType: HealthDataType) -> HealthSampleUploader? {
        guard let currentUploaderIndex = self.firstIndex(where: { $0.sampleDataType == dataType }) else {
            return nil
        }
        let nextUploaderIndex = currentUploaderIndex + 1
        guard nextUploaderIndex < self.count else {
            return nil
        }
        return self[nextUploaderIndex]
    }
    
    func getUploader(forDataType dataType: HealthDataType) -> HealthSampleUploader? {
        return self.first(where: { $0.sampleDataType == dataType })
    }
}

#endif
