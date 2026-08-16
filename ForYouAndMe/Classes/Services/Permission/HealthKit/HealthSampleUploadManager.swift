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

    /// FUAM-3841: the participant's enrollment date. Lower bound for the HealthKit backfill
    /// (HealthKit has no OS retention limit, so the enrollment date is the only bound) and
    /// hard consent gate for sample measurement timestamps. `nil` when no user is available.
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
    
    private let reachability: HealthSampleUploadManagerReachability
    private let analytics: AnalyticsService
    private let uploaders: [HealthSampleUploader]
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
    
    private func startUpload(forUploader uploader: HealthSampleUploader) {
        self.storage.pendingUploadDataType = uploader.sampleDataType

        guard self.reachability.isCurrentlyReachableForHealthSampleUpload else {
            self.logDebugText(text: "Upload sequence stopped due to not available connection")
            self.uploadSequenceScheduledOrRunning = false
            return
        }

        let enrollmentDate = self.clearanceDelegate?.enrollmentDate
        let dataType = uploader.sampleDataType

        // FUAM-3841: per-data-type cursor (review fix #4). When no cursor exists yet (fresh
        // install; legacy shared key covered by the storage fallback) backfill from the
        // enrollment date — HealthKit has no OS retention limit — or, when no enrollment
        // date is resolvable (e.g. days_in_study <= 0), from the legacy fixed window.
        var startDate: Date
        var minimumSampleDate = enrollmentDate
        if let storedStartDate = self.storage.uploadStartDate(forDataType: dataType) {
            startDate = storedStartDate
        } else if enrollmentDate == nil, HostAppConfig.healthKitIgnoresOptInConsent {
            // FUAM-3841 (final review): when clearance comes from the consent-bypass flag and
            // no enrollment date is resolvable, the legacy fixed window would upload data
            // measured BEFORE clearance. Forward-only: start now and floor the sample dates
            // at now so nothing pre-clearance leaks.
            startDate = Date()
            minimumSampleDate = startDate
            self.logDebugText(text: "Backfill lower bound for \(dataType.keyName) set to \(startDate) "
                              + "(consent bypass, forward-only)")
            self.analytics.track(event: .sensorDataBackfillReach(sensor: "health_kit_" + dataType.keyName,
                                                                 reachedBack: ISO8601DateFormatter().string(from: startDate),
                                                                 boundedBy: "consent_bypass_forward_only"))
        } else {
            startDate = enrollmentDate ?? Date(timeIntervalSinceNow: -Constants.HealthKit.SamplesStartDateTimeInThePast)
            self.logDebugText(text: "Backfill lower bound for \(dataType.keyName) set to \(startDate) "
                              + "(\(enrollmentDate != nil ? "enrollment" : "legacy fallback"))")
            self.analytics.track(event: .sensorDataBackfillReach(sensor: "health_kit_" + dataType.keyName,
                                                                 reachedBack: ISO8601DateFormatter().string(from: startDate),
                                                                 boundedBy: enrollmentDate != nil
                                                                    ? "enrollment" : "legacy_fixed_window"))
        }

        // FUAM-3841 hard consent gate: never query (nor transmit) anything measured before
        // the enrollment date, even if a stale stored start date predates it.
        if let enrollmentDate = enrollmentDate, startDate < enrollmentDate {
            startDate = enrollmentDate
        }

        let endDate = Date()
        let oneHour: TimeInterval = 3600
        let oneDay: TimeInterval = 24 * 3600
        // Review fixes #7/#8: while the cursor is far behind (historical walk) use coarse
        // 1-day chunks and a plain HKSampleQuery; near the head revert to 1-hour chunks and
        // the anchored query (Apple's guidance: sample queries for history, anchored for sync).
        let historicalThreshold: TimeInterval = 7 * oneDay

        func processNextChunk() {
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
