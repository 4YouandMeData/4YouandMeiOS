//
//  FirebaseAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/09/2020.
//

import Foundation
import FirebaseAnalytics

// TODO: Remove sample code

fileprivate enum FirebaseEventCustomName: String {
    case testFirebaseEvent = "test_firebase_event"
}

fileprivate enum FirebaseEventCustomParameter: String {
    case sampleParameter = "sample_parameter"
}

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .testFirebaseEvent(let sampleParameter):
            self.sendTestFirebaseEvent(sampleParameter: sampleParameter)
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func sendTestFirebaseEvent(sampleParameter: Int) {
        self.sendEvent(withEventName: FirebaseEventCustomName.testFirebaseEvent.rawValue,
                       parameters: [FirebaseEventCustomParameter.sampleParameter.rawValue: sampleParameter])
    }
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
}
