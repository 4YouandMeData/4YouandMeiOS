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

    /// Data types already reported as forward-only this launch (telemetry noise guard).
    private var forwardOnlyReported: Set<HealthDataType> = []

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
        let bound = BackfillLowerBound.resolve(joinDay: self.clearanceDelegate?.enrollmentDate)

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

        if storedStartDate == nil {
            self.logDebugText(text: "Backfill lower bound for \(dataType.keyName) set to \(startDate) "
                              + "(\(bound.origin.rawValue))")
            self.analytics.track(event: .sensorDataBackfillReach(sensor: "health_kit_" + dataType.keyName,
                                                                 reachedBack: ISO8601DateFormatter().string(from: startDate),
                                                                 boundedBy: bound.origin.rawValue))
        }

        let endDate = Date()
        let oneHour: TimeInterval = 3600
        let oneDay: TimeInterval = 24 * 3600
        // Review fixes #7/#8: while the cursor is far behind (historical walk) use coarse
        // 1-day chunks and a plain HKSampleQuery; near the head revert to 1-hour chunks and
        // the anchored query (Apple's guidance: sample queries for history, anchored for sync).
        let historicalThreshold: TimeInterval = 7 * oneDay

        func processNextChunk() {
            // FUAM-3945 (review round 4, I2): the walk cannot return anything once its start has
            // reached the end of the window, and persisting `nextEndDate` over a window that was
            // never read forfeits it for good. Skip the data type and leave the cursor ALONE, the
            // same contract as the forward-only skip above. The live case is a bound in the
            // FUTURE: the device clock jumped forward, so `BackfillClock`'s high-water mark keeps
            // the future value (and the join day with it) until real time catches up. Collection
            // is suspended meanwhile — deliberately, it is the price of the rollback guarantee —
            // but nothing is lost, and `sensor_data_clock_ahead` says so once per launch.
            guard startDate < endDate else {
                self.logDebugText(text: "Skipping \(dataType.keyName): start \(startDate) is not before "
                                  + "end \(endDate); cursor left untouched")
                self.processNextUploader(forUploader: uploader)
                return
            }

            let isHistorical = endDate.timeIntervalSince(startDate) > historicalThreshold
            let chunkDuration = isHistorical ? oneDay : oneHour
            let nextEndDate = min(startDate.addingTimeInterval(chunkDuration), endDate)

            uploader.run(startDate: startDate,
                         endDate: nextEndDate,
                         source: "health_kit",
                         minimumSampleDate: minimumSampleDate,
                         useAnchoredQuery: !isHistorical)
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.logDebugText(text: "Upload from \(startDate) to \(nextEndDate) completed")

                    // Review fix #7: persist progress after EACH chunk, so an interrupted
                    // multi-month walk resumes instead of restarting from enrollment.
                    self.storage.setUploadStartDate(nextEndDate, forDataType: dataType)

                    if nextEndDate < endDate {
                        startDate = nextEndDate
                        processNextChunk()  // Processa il chunk successivo
                    } else {
                        self.processNextUploader(forUploader: uploader)
                    }
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.logDebugText(text: "Upload failed from \(startDate) to \(nextEndDate) with error: \(error)")
                    
                    guard let sampleUploadError = error as? HealthSampleUploaderError else {
                        assertionFailure("Unexpected error type")
                        return
                    }
                    
                    switch sampleUploadError {
                    case .internalError, .fetchDataError, .unexpectedDataType, .uploadServerError:
                        self.logDebugText(text: "Upload error: \(sampleUploadError)")
                        self.processNextUploader(forUploader: uploader)
                    case .uploadConnectivityError:
                        self.logDebugText(text: "Upload connectivity error. Retrying current chunk")
                        processNextChunk()  // Riprova l'upload di questo chunk
                    }
                }).disposed(by: self.disposeBag)
        }

        processNextChunk()  // Avvia il primo chunk
    }

    /// Forward-only means "we could not establish the join day", which is actionable but
    /// permanent until the user record loads — report it at most once per data type per launch
    /// instead of on every hourly sequence.
    private func reportForwardOnlyOnce(forDataType dataType: HealthDataType, bound: BackfillLowerBound) {
        self.logDebugText(text: "Skipping \(dataType.keyName): no study join day, collection is forward-only")
        guard self.forwardOnlyReported.insert(dataType).inserted else { return }
        self.analytics.track(event: .sensorDataBackfillReach(sensor: "health_kit_" + dataType.keyName,
                                                             reachedBack: ISO8601DateFormatter().string(from: bound.date),
                                                             boundedBy: bound.origin.rawValue))
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
