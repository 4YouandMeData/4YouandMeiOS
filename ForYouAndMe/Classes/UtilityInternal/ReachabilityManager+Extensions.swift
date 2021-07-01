//
//  ReachabilityManager+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 01/07/21.
//

import Foundation
import RxSwift

// MARK: - BatchEventUploaderReachability

extension ReachabilityManager: BatchEventUploaderReachability {
    
    var isCurrentlyReachableForBatchEventUpload: Bool {
        return self.isCurrentlyReachable
    }
    
    func getIsReachableObserverForBatchEventUpload() -> Observable<Bool> {
        return self.getReachability().map { connectionType in
            switch connectionType {
            case .cellular, .wifi: return true
            case .none: return false
            }
        }
    }
}

// MARK: - HealthSampleUploadManagerReachability

extension ReachabilityManager: HealthSampleUploadManagerReachability {
    
    var isCurrentlyReachableForHealthSampleUpload: Bool {
        return self.currentReachabilityType.isCurrentlyReachableForHealthSampleUpload
    }
    
    func getIsReachableForHealthSampleUploadObserver() -> Observable<Bool> {
        return self.getReachability().map { $0.isCurrentlyReachableForHealthSampleUpload }
    }
}

fileprivate extension ReachabilityServiceType {
    var isCurrentlyReachableForHealthSampleUpload: Bool {
        return self != .none && Constants.HealthKit.ConnectionAvailabilityForUpload.contains(self)
    }
}
