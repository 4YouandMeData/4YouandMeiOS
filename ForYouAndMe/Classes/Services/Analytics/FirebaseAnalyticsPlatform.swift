//
//  FirebaseAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/09/2020.
//

import Foundation
import FirebaseAnalytics

private enum FirebaseEventCustomName: String {
    case userRegistration = "user_registration"
    case startStudyAction = "study_video_action"
    case cancelDuringScreeningQuestions = "screening_questions_cancelled"
    case cancelDuringConsentSummary = "consent_summary_cancelled"
    case cancelDuringConsent = "full_consent_cancelled"
    case cancelDuringAppsAndDevices = "apps_and_devices_cancelled"
    case cancelDuringComprehension = "comprehension_cancelled"
    case cancelDuringOptin = "optin_cancelled"
    case consentScreenLearnMore = "learn_more_clicked"
    case consentDisagreed = "consent_disagreed"
    case consentAgreed = "consent_agreed"
    case clickFeedTile = "feed_tile_clicked"
    case quickActivity = "quick_activity_option_clicked"
    case switchTab = "tab_switch"
    case videoDiaryAction = "video_diary_action"
    case yourDataSelectDataPeriod = "your_data_period_selection"
    case locationPermissionChanged = "location_permission_changed"
    case pushNotificationsPermissionChanged = "pushnotifications_permission_changed"
}

private enum FirebaseEventCustomParameter: String {
    case userId
    case start
    case pause
    case close
    case screenId = "screen_id"
    case tileId = "tile_id"
    case type
    case mood
    case energy
    case stress
    case action
    case submit
    case tab
    case feed
    case tasks
    case yourdata = "your_data"
    case studyInfo = "study_info"
    case dataPeriod = "data_period"
    case week
    case month
    case year
    case page
    case contact
    case faq
    case points
    case privacyPolicy
    case termsOfService
    case deviceId = "device_id"
    case accountType = "account_type"
    case uk = "UK"
    case us = "US"
    case option
    case recordingStarted = "start_recording"
    case recordingPaused = "pause_recording"
    case startPlaying = "start_playing"
    case pausePlaying = "pause_playing"
    case startOver = "start_over"
    case continueRecording = "continue_recording"
    case status
    case allow
    case revoke
}

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
//        case .testFirebaseEvent(let sampleParameter):
//            self.sendTestFirebaseEvent(sampleParameter: sampleParameter)
        case .setUserID(let userID):
            self.setUserID(userID)
        case .recordScreen(let screenName, let screenClass):
            self.sendRecordScreen(screenName: screenName, screenClass: screenClass)
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
//    private func sendTestFirebaseEvent(sampleParameter: Int) {
//        self.sendEvent(withEventName: FirebaseEventCustomName.testFirebaseEvent.rawValue,
//                       parameters: [FirebaseEventCustomParameter.sampleParameter.rawValue: sampleParameter])
//    }
    private func setUserID(_ userID: String) {
        Analytics.setUserID(userID)
    }
    
    private func sendRecordScreen(screenName: String, screenClass: String) {
        Analytics.setScreenName(screenName, screenClass: screenClass)
    }
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
}
