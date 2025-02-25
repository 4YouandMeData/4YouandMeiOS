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
}

protocol HealthSampleUploadManagerReachability {
    var isCurrentlyReachableForHealthSampleUpload: Bool { get }
    func getIsReachableForHealthSampleUploadObserver() -> Observable<Bool>
}

protocol HealthSampleUploadManagerStorage {
    var uploadStartDate: Date? { get set }
    var lastUploadSequenceCompletionDate: Date? { get set }
    var lastUploadSequenceStartingDate: Date? { get set }
    var pendingUploadDataType: HealthDataType? { get set }
}

#if HEALTHKIT
import HealthKit

class HealthSampleUploadManager {
    
    private var storage: HealthSampleUploadManagerStorage
    weak var clearanceDelegate: HealthSampleUploadManagerClearanceDelegate?
    
    private var uploadSequenceScheduledOrRunning: Bool = false
    
    private let reachability: HealthSampleUploadManagerReachability
    private let uploaders: [HealthSampleUploader]
    private let disposeBag = DisposeBag()
    
    init(withDataTypes dataTypes: [HealthDataType],
         storage: HealthSampleUploadManagerStorage & HealthSampleUploaderStorage,
         reachability: HealthSampleUploadManagerReachability) {
        self.storage = storage
        self.reachability = reachability
        let sampleTypes = dataTypes
            .filter { $0.sampleType != nil }
            .filter { $0.isValid }
        self.uploaders = sampleTypes.map { HealthSampleUploader(withSampleDataType: $0, storage: storage) }
        self.logDebugText(text: "Initialized with \(self.uploaders.count) uploaders")
        if nil == self.storage.uploadStartDate {
            self.storage.uploadStartDate = Date(timeIntervalSinceNow: -Constants.HealthKit.SamplesStartDateTimeInThePast)
        }
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
            self.logDebugText(text: "Upload sequence has no clearance")
            self.storage.lastUploadSequenceCompletionDate = Date()
            self.uploadSequenceScheduledOrRunning = false
            self.scheduleUploadSequence()
            return
        }
        
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

        guard var startDate = self.storage.uploadStartDate else {
            assertionFailure("Upload start date has not been initialized")
            return
        }

        let endDate = Date()
        let oneHour: TimeInterval = 3600

        func processNextChunk() {
            let nextEndDate = min(startDate.addingTimeInterval(oneHour), endDate)
            
            uploader.run(startDate: startDate, endDate: nextEndDate)
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.logDebugText(text: "Upload from \(startDate) to \(nextEndDate) completed")
                    
                    if nextEndDate < endDate {
                        startDate = nextEndDate
                        processNextChunk()  // Processa il chunk successivo
                    } else {
                        self.storage.uploadStartDate = endDate  // Aggiorna dopo aver processato tutto
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
