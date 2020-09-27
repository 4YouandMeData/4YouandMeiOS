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
    case cancelDuringInformedConsent = "informed_consent_cancelled"
    case cancelDuringComprehension = "comprehension_quiz_cancelled"
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

class FirebaseAnalyticsPlatform: AnalyticsPlatform {
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .setUserID(let userID):
            self.setUserID(userID)
        case .setUserPropertyString(let value, let name):
            self.setUserPropertyString(value, forName: name)
        case .recordScreen(let screenName, let screenClass):
            self.sendRecordScreen(screenName: screenName, screenClass: screenClass)
        case .userRegistration(let accountType):
            self.userRegistration(accountType)
        case .startStudyAction(let actionType):
            self.startStudyAction(actionType)
        case .cancelDuringScreeningQuestion(let questionID):
            self.cancelDuringScreeningQuestion(questionID)
        case .cancelDuringInformedConsent(let pageID):
            self.cancelDuringInformedConsent(pageID)
        case .cancelDuringComprehensionQuiz(let question):
            self.cancelDuringComprehension(question)
        case .consentAgreed:
            self.consentAgreed()
        case .consentDisagreed:
            self.consentDisagreed()
        case .switchTab(let tabName):
            self.switchTab(tabName)
        case .quickActivity(let quickActivityID, let option):
            self.quickActivityCLicked(quickActivityID, option: option)
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
//    private func sendTestFirebaseEvent(sampleParameter: Int) {
//        self.sendEvent(withEventName: FirebaseEventCustomName.testFirebaseEvent.rawValue,
//                       parameters: [FirebaseEventCustomParameter.sampleParameter.rawValue: sampleParameter])
//    }
    
    //User
    private func setUserID(_ userID: String) {
        Analytics.setUserID(userID)
    }
    
    func setUserPropertyString(_ value: String?, forName: String) {
        Analytics.setUserProperty(value, forName: forName)
    }
    
    func userRegistration(_ accountType: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.userRegistration.rawValue,
                       parameters: [AnalyticsParameter.accountType.rawValue: accountType])
    }
    
    //Onboarding
    func startStudyAction(_ actionType: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.startStudyAction.rawValue,
                       parameters: [AnalyticsParameter.action.rawValue: actionType])
    }
    
    func cancelDuringScreeningQuestion(_ questionID: String? = nil) {
        self.sendEvent(withEventName: FirebaseEventCustomName.cancelDuringScreeningQuestions.rawValue,
                       parameters: [AnalyticsParameter.screenId.rawValue: questionID ?? ""])
    }
    
    func cancelDuringInformedConsent(_ pageID: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.cancelDuringInformedConsent.rawValue,
                       parameters: [AnalyticsParameter.screenId.rawValue: pageID])
    }
    
    func cancelDuringComprehension(_ questionID: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.cancelDuringComprehension.rawValue,
                       parameters: [AnalyticsParameter.screenId.rawValue: questionID])
    }
    
    func consentDisagreed() {
        self.sendEvent(withEventName: FirebaseEventCustomName.consentDisagreed.rawValue)
    }
    
    func consentAgreed() {
        self.sendEvent(withEventName: FirebaseEventCustomName.consentAgreed.rawValue)
    }

    //Main App
    func switchTab(_ tabName: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.switchTab.rawValue,
                       parameters: [AnalyticsParameter.tab.rawValue : tabName])
    }
    func quickActivityCLicked(_ activityID: String, option: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.quickActivity.rawValue,
                       parameters: [AnalyticsParameter.option.rawValue : option,
                                    AnalyticsParameter.tileId.rawValue : activityID])
    }
//
//    func switchTab(_ tabName: String) {
//        self.sendEvent(withEventName: FirebaseEventCustomName.switchTab.rawValue,
//                       parameters: [AnalyticsParameter.tab.rawValue: tabName])
//    }
//
//    func videoDiaryAction(_ actionType: String) {
//        self.sendEvent(withEventName: FirebaseEventCustomName.videoDiaryAction.rawValue,
//                       parameters: [AnalyticsParameter.action.rawValue: actionType])
//    }
//
//    func yurDataSelectPeriod(_ period: String) {
//        self.sendEvent(withEventName: FirebaseEventCustomName.yourDataSelectDataPeriod.rawValue,
//                       parameters: [AnalyticsParameter.dataPeriod.rawValue: period])
//    }
//
//    func locationPermissionChanged(_ allow: String) {
//        self.sendEvent(withEventName: FirebaseEventCustomName.locationPermissionChanged.rawValue,
//                       parameters: [AnalyticsParameter.status.rawValue: allow])
//    }
//
//    func notificationPermissionChanged(_ allow: String) {
//        self.sendEvent(withEventName: FirebaseEventCustomName.pushNotificationsPermissionChanged.rawValue,
//                       parameters: [AnalyticsParameter.status.rawValue: allow])
//    }
    
    //Screens
    
    private func sendRecordScreen(screenName: String, screenClass: String) {
        Analytics.setScreenName(screenName, screenClass: screenClass)
    }
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
}
