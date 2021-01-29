//
//  BatchEventUploader.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/01/21.
//

import Foundation
import RxSwift

struct Buffer<Record: Codable>: Codable {
    var records: [Record]
    
    init(records: [Record]) {
        self.records = records
    }
}

struct BatchEventUploaderConfig {
    /// Unique identifier for the uploader.
    let identifier: String
    
    /// Interval between battery samples (each one is added to the current buffer for batch upload)
    let defaultRecordInterval: TimeInterval
    
    /// Interval between sending archieved battery buffers when connected to the internet.
    /// If nil, all records are sent right away, without batching
    let uploadInterval: TimeInterval?
    
    /// Interval between retrys on sending archieved battery buffers when connected to the internet
    let uploadRetryInterval: TimeInterval
    
    /// max number of batter buffers. If the limit is exceeded, the oldest buffer is discarded
    let bufferLimit: Int
    
    /// Enable debug console logs?
    let enableDebugLog: Bool
}

protocol BatchEventUploaderReachability {
    var isCurrentlyReachable: Bool { get }
    func getIsReachableObserver() -> Observable<Bool>
}

enum BatchEventUploaderDateType: String {
    case nextBufferUploadDate, nextBufferUploadRetryDate, nextBufferRecord
}

protocol BatchEventUploaderStorage {
    func appendRecord<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String, record: Record)
    func archiveCurrentBuffer<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String, bufferLimit: Int, type: Record.Type)
    func removeOldestArchivedBuffer<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String, type: Record.Type)
    func getOldestArchivedBuffer<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String) -> Buffer<Record>?
    func resetAllBuffers(forUploaderIdentifier uploaderIdentifier: String)
    // Dates
    func getBatchEventUploaderDate(forUploaderIdentifier uploaderIdentifier: String, dateType: BatchEventUploaderDateType) -> Date?
    func saveBatchEventUploaderDate(forUploaderIdentifier uploaderIdentifier: String, dateType: BatchEventUploaderDateType, date: Date)
    func resetBatchEventUploaderDate(forUploaderIdentifier uploaderIdentifier: String, dateType: BatchEventUploaderDateType)
    // Record Interval
    func getRecordInterval(forUploaderIdentifier uploaderIdentifier: String) -> TimeInterval?
    func saveRecordInterval(forUploaderIdentifier uploaderIdentifier: String, timeInterval: TimeInterval)
}

class BatchEventUploader<Record: Codable> {
    
    typealias GetRecordClosure = (() -> (Record?))
    typealias GetUploadRequestClosure = ((Buffer<Record>) -> Single<()>)
    
    public var setupCompleted: Bool = false
    
    private let config: BatchEventUploaderConfig
    private let storage: BatchEventUploaderStorage
    private let reachability: BatchEventUploaderReachability
    
    private let disposeBag = DisposeBag()
    
    private var isRunning: Bool { self.recordInterval > 0 }
    
    private var recordTimer: Timer?
    private var uploadTimer: Timer?
    private var uploadRetryTimer: Timer?
    
    private var getRecord: GetRecordClosure?
    private var getUploadRequest: GetUploadRequestClosure?
    
    private var recordInterval: TimeInterval {
        self.storage.getRecordInterval(forUploaderIdentifier: self.config.identifier) ?? self.config.defaultRecordInterval
    }
    
    init(withConfig config: BatchEventUploaderConfig, storage: BatchEventUploaderStorage, reachability: BatchEventUploaderReachability) {
        self.config = config
        self.storage = storage
        self.reachability = reachability
    }
    
    // MARK: - Public Methods
    
    public func setup(getRecord: @escaping GetRecordClosure, getUploadRequest: @escaping GetUploadRequestClosure) {
        guard self.setupCompleted == false else { return }
        
        self.setupCompleted = true
        
        self.getRecord = getRecord
        self.getUploadRequest = getUploadRequest
        
        self.setupBuffersRecordTimer()
        self.setupBuffersUploadTimer()
        self.setupBuffersUploadRetryTimer()
        
        self.reachability.getIsReachableObserver()
            .subscribe(onNext: { [weak self] isReachable in
                guard let self = self else { return }
                if isReachable, nil != self.storage.getBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier,
                                                                              dateType: .nextBufferUploadRetryDate) {
                    self.logDebugText(text: "Connection re-established while in retry state. Upload Buffers")
                    self.uploadBuffers()
                }
            }).disposed(by: self.disposeBag)
    }
    
    public func setRecordInterval(recordInterval: TimeInterval) {
        if self.storage.getRecordInterval(forUploaderIdentifier: self.config.identifier) != recordInterval {
            self.storage.saveRecordInterval(forUploaderIdentifier: self.config.identifier, timeInterval: recordInterval)
            self.logDebugText(text: "Refreshed Record interval. New Value \(recordInterval)")
            if self.isRunning {
                self.logDebugText(text: "Performing reschedule (is running behaviour)")
                self.scheduleBuffersRecord(timeInterval: self.recordInterval)
                if let uploadInterval = self.config.uploadInterval, self.uploadTimer == nil {
                    self.scheduleBuffersUpload(timeInterval: uploadInterval)
                }
            } else {
                self.logDebugText(text: "Resetting schedule and buffer (is not running behaviour)")
                self.resetRecordTimer()
                self.resetUploadTimer()
                self.resetUploadRetryTimer()
                self.resetAllBuffers()
            }
        } else {
            self.logDebugText(text: "Refreshed Record interval. Value \(recordInterval) unchanged. Do Nothing")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBuffersRecordTimer() {
        guard self.isRunning else {
            self.logDebugText(text: "No running state. Reset Buffer Record Scheduler")
            self.resetRecordTimer()
            return
        }
        
        if let nextBufferRecordDate = self.storage.getBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier,
                                                                             dateType: .nextBufferRecord) {
            if nextBufferRecordDate < Date() {
                self.logDebugText(text: "Expired Buffer Record Scheduler. Add new record and reschedule")
                self.addRecordFromUpdate()
                self.scheduleBuffersRecord(timeInterval: self.recordInterval)
            } else {
                let timeInterval = nextBufferRecordDate.timeIntervalSince(Date())
                self.logDebugText(text: "Restoring Buffer Record Scheduler. Next tick in \(timeInterval)s")
                self.scheduleBuffersRecord(timeInterval: timeInterval)
            }
        } else {
            self.logDebugText(text: "No existing Buffer Record Scheduler found. Schedule")
            self.scheduleBuffersRecord(timeInterval: self.recordInterval)
        }
    }
    
    private func setupBuffersUploadTimer() {
        guard self.isRunning else {
            self.logDebugText(text: "No running state. Reset Buffer Upload Scheduler")
            self.resetUploadTimer()
            return
        }
        
        if let uploadInterval = self.config.uploadInterval {
            if let nextBufferUploadDate = self.storage.getBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier,
                                                                                 dateType: .nextBufferUploadDate) {
                if nextBufferUploadDate < Date() {
                    self.logDebugText(text: "Expired Buffer Upload Scheduler. Archive Current Buffer, Upload Buffers and reschedule")
                    self.archiveAndUpload()
                    self.scheduleBuffersUpload(timeInterval: uploadInterval)
                } else {
                    let timeInterval = nextBufferUploadDate.timeIntervalSince(Date())
                    self.logDebugText(text: "Restoring Buffer Upload Scheduler. Next tick in \(timeInterval)s")
                    self.scheduleBuffersUpload(timeInterval: timeInterval)
                }
            } else {
                self.logDebugText(text: "No existing Buffer Upload Scheduler found. Schedule")
                self.scheduleBuffersUpload(timeInterval: uploadInterval)
            }
        } else {
            self.logDebugText(text: "No Upload Interval value provided. No Upload Schedule should be started")
        }
    }
    
    private func setupBuffersUploadRetryTimer() {
        guard self.isRunning else {
            self.logDebugText(text: "No running state. Reset Buffer Upload Retry Scheduler")
            self.resetUploadRetryTimer()
            return
        }
        
        if let nextBufferUploadRetryDate = self.storage.getBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier,
                                                                                  dateType: .nextBufferUploadRetryDate) {
            if nextBufferUploadRetryDate < Date() {
                self.logDebugText(text: "Expired Buffer Upload Retry Scheduler. Upload Buffers")
                self.uploadBuffers()
            } else {
                let timeInterval = nextBufferUploadRetryDate.timeIntervalSince(Date())
                self.logDebugText(text: "Restoring Buffer Upload Retry Scheduler. Next tick in \(timeInterval)s")
                self.scheduleBuffersUploadRetry(timeInterval: timeInterval)
            }
        }
    }
    
    private func scheduleBuffersRecord(timeInterval: TimeInterval) {
        self.resetRecordTimer()
        self.storage.saveBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier,
                                                dateType: .nextBufferRecord,
                                                date: Date(timeIntervalSinceNow: timeInterval))
        self.recordTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false, block: { [weak self] _ in
            guard let self = self else { return }
            self.logDebugText(text: "Buffer Record Timer Tick. Add Record From Update and reschedule")
            self.addRecordFromUpdate()
            self.scheduleBuffersRecord(timeInterval: self.recordInterval)
        })
    }
    
    private func scheduleBuffersUpload(timeInterval: TimeInterval) {
        self.resetUploadTimer()
        self.storage.saveBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier,
                                                dateType: .nextBufferUploadDate,
                                                date: Date(timeIntervalSinceNow: timeInterval))
        self.uploadTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false, block: { [weak self] _ in
            guard let self = self else { return }
            self.logDebugText(text: "Buffer Upload Timer Tick. archive current buffer, upload buffers and reschedule")
            self.archiveAndUpload()
            if let uploadInterval = self.config.uploadInterval {
                self.scheduleBuffersUpload(timeInterval: uploadInterval)
            }
        })
    }
    
    private func scheduleBuffersUploadRetry(timeInterval: TimeInterval) {
        self.resetUploadRetryTimer()
        self.storage.saveBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier,
                                                dateType: .nextBufferUploadRetryDate,
                                                date: Date(timeIntervalSinceNow: timeInterval))
        self.uploadRetryTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false, block: { [weak self] _ in
            guard let self = self else { return }
            if self.reachability.isCurrentlyReachable {
                self.logDebugText(text: "Buffer Upload Retry Timer Tick. Connection available -> Upload buffers")
                self.uploadBuffers()
            } else {
                self.logDebugText(text: "Buffer Upload Retry Timer Tick. Connection unavailable -> Do Nothing")
            }
        })
    }
    
    private func resetRecordTimer() {
        self.recordTimer?.invalidate()
        self.recordTimer = nil
        self.storage.resetBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier, dateType: .nextBufferRecord)
    }
    
    private func resetUploadTimer() {
        self.uploadTimer?.invalidate()
        self.uploadTimer = nil
        self.storage.resetBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier, dateType: .nextBufferUploadDate)
    }
    
    private func resetUploadRetryTimer() {
        self.uploadRetryTimer?.invalidate()
        self.uploadRetryTimer = nil
        self.storage.resetBatchEventUploaderDate(forUploaderIdentifier: self.config.identifier, dateType: .nextBufferUploadRetryDate)
    }
    
    private func resetAllBuffers() {
        self.storage.resetAllBuffers(forUploaderIdentifier: self.config.identifier)
    }
    
    public func addRecord(record: Record) {
        guard self.isRunning else {
            self.logDebugText(text: "Trying to add record in no running state. Do Nothing")
            return
        }
        
        self.logDebugText(text: "Appending record to current buffer: \(record)")
        self.storage.appendRecord(forUploaderIdentifier: self.config.identifier, record: record)
        // If no upload interval is given, upload all buffers as soon as a new record is provided (no batch)
        if nil == self.config.uploadInterval {
            self.logDebugText(text: "No Upload Interval Provided. Archive current buffer and upload buffers right away.")
            self.archiveAndUpload()
        }
    }
    
    private func archiveAndUpload() {
        self.storage.archiveCurrentBuffer(forUploaderIdentifier: self.config.identifier,
                                          bufferLimit: self.config.bufferLimit,
                                          type: Record.self)
        self.uploadBuffers()
    }
    
    private func uploadBuffers() {
        self.resetUploadRetryTimer()
        
        guard self.isRunning else {
            self.logDebugText(text: "Trying to add upload buffers in no running state. Do Nothing")
            return
        }
        
        guard let buffer: Buffer<Record> = self.storage.getOldestArchivedBuffer(forUploaderIdentifier: self.config.identifier) else {
            self.logDebugText(text: "No archieved buffers to upload")
            return
        }
        
        guard let uploadRequest = self.getUploadRequest?(buffer) else {
            self.logDebugText(text: "Missing Upload Request")
            return
        }
        
        self.logDebugText(text: "Uploading oldest buffer: \(buffer)")
        
        uploadRequest
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.logDebugText(text: "Buffer Upload success. Removing it from archived buffers array and recursively upload buffers")
                self.storage.removeOldestArchivedBuffer(forUploaderIdentifier: self.config.identifier, type: Record.self)
                self.uploadBuffers()
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.logDebugText(text: "Buffer Upload failed. Schedule Upload Retry. Error: \(error)")
                self.scheduleBuffersUploadRetry(timeInterval: self.config.uploadRetryInterval)
            }).disposed(by: self.disposeBag)
    }
    
    private func addRecordFromUpdate() {
        guard let record = self.getRecord?() else { return }
        self.addRecord(record: record)
    }
    
    private func logDebugText(text: String) {
        #if DEBUG
        if self.config.enableDebugLog {
            print("BatchEventUploader.\(self.config.identifier) - \(text)")
        }
        #endif
    }
}
