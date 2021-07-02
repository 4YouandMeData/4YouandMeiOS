//
//  HealthSampleUploadManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/06/21.
//

import Foundation
import RxSwift

protocol HealthSampleUploadManagerReachability {
    var isCurrentlyReachableForHealthSampleUpload: Bool { get }
    func getIsReachableForHealthSampleUploadObserver() -> Observable<Bool>
}

protocol HealthSampleUploadManagerStorage: HealthSampleUploaderStorage {
    var lastCompletedUploaderDataType: HealthDataType? { get set }
}

#if HEALTHKIT
import HealthKit

class HealthSampleUploadManager {
    
    private var storage: HealthSampleUploadManagerStorage
    private var reachability: HealthSampleUploadManagerReachability
    
    private let uploaders: [HealthSampleUploader]
    
    private var uploadSequenceTimerDisposable: Disposable?
    private var uploadDisposable: Disposable?
    
    private let disposeBag = DisposeBag()
    
    init(withDataTypes dataTypes: [HealthDataType],
         storage: HealthSampleUploadManagerStorage,
         reachability: HealthSampleUploadManagerReachability) {
        self.storage = storage
        self.reachability = reachability
        let sampleTypes = dataTypes
            .filter { $0.sampleType != nil }
            .filter { $0.isValid }
        self.uploaders = sampleTypes.map { HealthSampleUploader(withSampleDataType: $0, storage: storage) }
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
        
        self.scheduleUploadSequence()
        
        self.reachability.getIsReachableForHealthSampleUploadObserver()
            .subscribe(onNext: { [weak self] reachable in
                guard let self = self else { return }
                if reachable, self.uploadSequenceTimerDisposable != nil {
                    self.scheduleUploadSequence()
                }
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: - Private Methods
    
    private func scheduleUploadSequence() {
        let dueTimeSeconds: Int
        if let lastUploadSequenceCompletionDate = self.storage.lastUploadSequenceCompletionDate {
            let nextUploadSequenceDate = lastUploadSequenceCompletionDate.addingTimeInterval(Constants.HealthKit.UploadSequenceTimeInterval)
            dueTimeSeconds = max(0, Int(nextUploadSequenceDate.timeIntervalSinceNow))
        } else {
            dueTimeSeconds = 0
        }
        
        if dueTimeSeconds == 0 {
            // Since we have to restart the entire sequence, clear any record of the last complete data type
            self.storage.lastCompletedUploaderDataType = nil
        }
        
        self.uploadSequenceTimerDisposable = Observable<Int>.timer(.seconds(dueTimeSeconds),
                              period: .seconds(Int(Constants.HealthKit.UploadSequenceTimeInterval)),
                              scheduler: MainScheduler.asyncInstance)
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.startUploadSequence()
            })
    }
    
    private func startUploadSequence() {
        self.logDebugText(text: "Upload sequence started")
        if let pendingUploader = self.getPendingUploader() {
            self.startUpload(forUploader: pendingUploader)
        } else if let firstUploader = self.uploaders.first {
            self.startUpload(forUploader: firstUploader)
        } else {
            self.logDebugText(text: "No sample data types to be uploaded")
        }
    }
    
    private func startUpload(forUploader uploader: HealthSampleUploader) {
        guard self.reachability.isCurrentlyReachableForHealthSampleUpload else {
            // If network connection is not available, unschedule the upload sequence, waiting for connection to be re-established.
            self.uploadSequenceTimerDisposable?.dispose()
            self.uploadSequenceTimerDisposable = nil
            return
        }
        
        self.logDebugText(text: "Upload for data type '\(uploader.sampleDataType.keyName)' started")
        self.uploadDisposable = uploader.run()
            .subscribe(onSuccess: {
                self.uploadDisposable = nil
                self.logDebugText(text: "Upload for data type '\(uploader.sampleDataType.keyName)' completed")
                self.processNextUploader(forUploader: uploader)
            }, onError: { error in
                self.uploadDisposable = nil
                self.logDebugText(text: "Data Type '\(uploader.sampleDataType.keyName)' upload failed with error: \(error)")
                guard let sampleUploadError = error as? HealthSampleUploaderError else {
                    assertionFailure("Unexpected error type")
                    return
                }
                switch sampleUploadError {
                case .internalError, .fetchDataError, .unexpectedDataType, .readPermissionDenied, .uploadServerError:
                    self.processNextUploader(forUploader: uploader)
                case .uploadConnectivityError:
                    // Restart the same upload. At the beginning of the method, if connection is still unavailable,
                    // the upload sequence will be unscheduled.
                    self.startUpload(forUploader: uploader)
                }
            })
    }
    
    private func processNextUploader(forUploader uploader: HealthSampleUploader) {
        self.storage.lastCompletedUploaderDataType = uploader.sampleDataType
        if let nextUploader = self.uploaders.getNextUploader(forDataType: uploader.sampleDataType) {
            self.startUpload(forUploader: nextUploader)
        } else {
            self.logDebugText(text: "Upload sequence completed")
            self.storage.lastUploadSequenceCompletionDate = Date()
            // This data is reset since it's only needed to restore interrupted uploads.
            self.storage.lastCompletedUploaderDataType = nil
        }
    }
    
    private func getPendingUploader() -> HealthSampleUploader? {
        if let lastCompletedUploaderDataType = self.storage.lastCompletedUploaderDataType {
            return self.uploaders.getNextUploader(forDataType: lastCompletedUploaderDataType)
        } else {
            return nil
        }
    }
    
    private func logDebugText(text: String) {
        #if DEBUG
        print("HealthSampleUploadManager - \(text)")
        #endif
    }
}

#endif

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
}
