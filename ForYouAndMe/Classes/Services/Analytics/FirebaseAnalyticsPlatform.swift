//
//  FirebaseAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/09/2020.
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

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

private enum FirebaseErrorDomain {
    case serverError(requestName: String)
    
    var stringValue: String {
        switch self {
        case .serverError(let pathUrl): return "Server Error - \(pathUrl)"
        }
    }
}

private enum FirebaseErrorCustomUserInfo: String {
    case networkRequestUrl = "network_request_url"
    case networkErrorType = "network_error_type"
    case networkRequestBody = "network_request_body"
    case networkResponseBody = "network_response_body"
    case networkUnderlyingError = "network_underlying_error"
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
        case .yourDataSelectionPeriod(let period):
            self.yurDataSelectPeriod(period)
        case .quickActivity(let quickActivityID, let option):
            self.quickActivityCLicked(quickActivityID, option: option)
        case .locationPermissionChanged(let status):
            self.locationPermissionChanged(status)
        case .notificationPermissionChanged(let status):
            self.notificationPermissionChanged(status)
        case .videoDiaryAction(let action):
            self.videoDiaryAction(action)
        case .serverError(let apiError):
            self.serverError(withApiError: apiError)
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    // MARK: User
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
    
    // MARK: Onboarding
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

    // MARK: Main App
    func switchTab(_ tabName: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.switchTab.rawValue,
                       parameters: [AnalyticsParameter.tab.rawValue: tabName])
    }
    
    func quickActivityCLicked(_ activityID: String, option: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.quickActivity.rawValue,
                       parameters: [AnalyticsParameter.option.rawValue: option,
                                    AnalyticsParameter.tileId.rawValue: activityID])
    }
    
    func yurDataSelectPeriod(_ period: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.yourDataSelectDataPeriod.rawValue,
                       parameters: [AnalyticsParameter.dataPeriod.rawValue: period])
    }
    
    // MARK: Task

    func videoDiaryAction(_ actionType: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.videoDiaryAction.rawValue,
                       parameters: [AnalyticsParameter.action.rawValue: actionType])
    }
    
    // MARK: Permission

    func locationPermissionChanged(_ allow: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.locationPermissionChanged.rawValue,
                       parameters: [AnalyticsParameter.status.rawValue: allow])
    }

    func notificationPermissionChanged(_ allow: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.pushNotificationsPermissionChanged.rawValue,
                       parameters: [AnalyticsParameter.status.rawValue: allow])
    }
    
    // MARK: Errors
    
    func serverError(withApiError apiError: ApiError) {
        switch apiError {
        case .connectivity: break // Reachability errors won't be tracked
        case let .cannotParseData(pathUrl, request, statusCode, responseBody):
            self.reportServerError(withErrorType: "parse_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: statusCode,
                                   request: request,
                                   responseBody: responseBody)
        case let .network(pathUrl, request, underlyingError):
            self.reportServerError(withErrorType: "network_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: 502,
                                   request: request,
                                   underlyingError: underlyingError)
        case let .unexpectedError(pathUrl, request, statusCode, responseBody):
            self.reportServerError(withErrorType: "server_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: statusCode,
                                   request: request,
                                   responseBody: responseBody)
        case let .expectedError(pathUrl, request, statusCode, responseBody, _):
            self.reportServerError(withErrorType: "unhandled_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: statusCode,
                                   request: request,
                                   responseBody: responseBody)
        case .userUnauthorized: break // User Unauthorized errors are expected and handled correctly by the app
        }
    }
    
    // MARK: Screens
    
    private func sendRecordScreen(screenName: String, screenClass: String) {
        Analytics.setScreenName(screenName, screenClass: screenClass)
    }
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
    
    private func reportServerError(withErrorType errorType: String,
                                   domain: FirebaseErrorDomain,
                                   pathUrl: String,
                                   statusCode: Int,
                                   request: ApiRequest,
                                   responseBody: String? = nil,
                                   underlyingError: Error? = nil) {
        var userInfo: [String: Any] = [:]
        userInfo[FirebaseErrorCustomUserInfo.networkErrorType.rawValue] = errorType
        userInfo[FirebaseErrorCustomUserInfo.networkRequestUrl.rawValue] = pathUrl
        if let requestBody = request.body {
            userInfo[FirebaseErrorCustomUserInfo.networkRequestBody.rawValue] = requestBody
        }
        if let responseBody = responseBody {
            userInfo[FirebaseErrorCustomUserInfo.networkResponseBody.rawValue] = responseBody
        }
        if let underlyingError = underlyingError {
            userInfo[FirebaseErrorCustomUserInfo.networkUnderlyingError.rawValue] = underlyingError
        }
        self.reportNonFatalError(withDomain: domain, statusCode: statusCode, userInfo: userInfo)
    }
        
    private func reportNonFatalError(withDomain domain: FirebaseErrorDomain, statusCode: Int, userInfo: [String: Any]? = nil) {
        let nsError = NSError(domain: domain.stringValue, code: statusCode, userInfo: userInfo)
        print("FirebaseAnalyticsPlatform - Record Non Fatal Error: \(nsError)")
        Crashlytics.crashlytics().record(error: nsError)
    }
}
