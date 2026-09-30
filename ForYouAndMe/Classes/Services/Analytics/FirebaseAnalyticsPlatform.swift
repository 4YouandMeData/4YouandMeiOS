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
    // FUAM-3021. Opt-in permission-chain watchdog (Approach B from FUAM-3020).
    case permissionWatchdogTimeout = "onboarding_permission_watchdog_tripped"
    case permissionWatchdogRetry = "onboarding_permission_retry"
    case permissionWatchdogSkipped = "onboarding_permission_skipped"
    // FUAM-3844. Sensor-data clearance mismatch watchdog.
    case sensorDataClearanceMismatch = "sensor_data_clearance_mismatch"
    // FUAM-3841. Backfill reach per sensor.
    case sensorDataBackfillReach = "sensor_data_backfill_reach"
    // FUAM-3945 / FUAM-3964. Device clock diverging from the server clock.
    case sensorDataClockAhead = "sensor_data_clock_ahead"
    // FUAM-3945 round 7. A SensorKit reader failed to start recording.
    case sensorRecordingStartFailed = "sensor_recording_start_failed"
    // FUAM-3945 round 8. Configured sensors the host has no entitlement for.
    case sensorEntitlementMissing = "sensor_entitlement_missing"
    // FUAM-3945 round 9 (D12/AC8). Windowing observability.
    case sensorWindowEmpty = "sensor_window_empty"
    case sensorRescanNovel = "sensor_rescan_novel"
    case sensorDeletionRecord = "sensor_deletion_record"
    case sensorNearDuplicate = "sensor_near_duplicate"
    case sensorRefused = "sensor_refused"
    case sensorDeepestWindow = "sensor_deepest_window"
    case sensorRecordDropped = "sensor_record_dropped"
    // FUAM-3945 fidelity audit (X1). Documented field absent from mapped entries.
    case sensorFieldMissing = "sensor_field_missing"
    case sensorTimezoneFallback = "sensor_tz_fallback"
}

private enum FirebaseErrorDomain {
    case serverError(requestName: String)
    case healthError(errorName: String)
    
    var stringValue: String {
        switch self {
        case .serverError(let requestName): return "Server Error - \(requestName)"
        case .healthError(let errorName): return "Health Error - \(errorName)"
        }
    }
}

private enum FirebaseErrorCustomUserInfo: String {
    case networkRequestUrl = "network_request_url"
    case networkErrorType = "network_error_type"
    case networkRequestBody = "network_request_body"
    case networkResponseBody = "network_response_body"
    case networkUnderlyingError = "network_underlying_error"
    case healthUnderlyingError = "health_underlying_error"
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
        case .healthError(let healthError):
            self.healthError(withHealthError: healthError)
        case .permissionWatchdogTimeout(let branch, let previousBranch, let elapsedMs, let attempt):
            self.permissionWatchdogTimeout(branch: branch,
                                           previousBranch: previousBranch,
                                           elapsedMs: elapsedMs,
                                           attempt: attempt)
        case .permissionWatchdogRetry(let branch, let attempt):
            self.permissionWatchdogRetry(branch: branch, attempt: attempt)
        case .permissionWatchdogSkipped(let branch, let wasFirstAttempt):
            self.permissionWatchdogSkipped(branch: branch, wasFirstAttempt: wasFirstAttempt)
        case .sensorDataClearanceMismatch(let reason, let authorizedSensors):
            self.sensorDataClearanceMismatch(reason: reason, authorizedSensors: authorizedSensors)
        case .sensorDataBackfillReach(let sensor, let reachedBack, let boundedBy):
            self.sensorDataBackfillReach(sensor: sensor, reachedBack: reachedBack, boundedBy: boundedBy)
        case .sensorDataClockAhead(let mark, let deviceNow):
            self.sensorDataClockAhead(mark: mark, deviceNow: deviceNow)
        case .sensorRecordingStartFailed(let sensor, let error):
            self.sensorRecordingStartFailed(sensor: sensor, error: error)
        case .sensorEntitlementMissing(let sensors, let count):
            self.sensorEntitlementMissing(sensors: sensors, count: count)
        case .sensorWindowEmpty(let sensor, let device, let windowDay, let pass):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorWindowEmpty.rawValue,
                           parameters: [
                               AnalyticsParameter.sensor.rawValue: sensor,
                               AnalyticsParameter.device.rawValue: device,
                               AnalyticsParameter.windowDay.rawValue: windowDay,
                               AnalyticsParameter.pass.rawValue: pass
                           ])
        case .sensorRescanNovel(let sensor, let device, let ageDays, let novelCount):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorRescanNovel.rawValue,
                           parameters: [
                               AnalyticsParameter.sensor.rawValue: sensor,
                               AnalyticsParameter.device.rawValue: device,
                               AnalyticsParameter.ageDays.rawValue: ageDays,
                               AnalyticsParameter.novelCount.rawValue: novelCount
                           ])
        case .sensorDeletionRecord(let sensor, let reason, let spanSeconds):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorDeletionRecord.rawValue,
                           parameters: [
                               AnalyticsParameter.sensor.rawValue: sensor,
                               AnalyticsParameter.reason.rawValue: reason,
                               AnalyticsParameter.spanSeconds.rawValue: spanSeconds
                           ])
        case .sensorNearDuplicate(let sensor, let count):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorNearDuplicate.rawValue,
                           parameters: [
                               AnalyticsParameter.sensor.rawValue: sensor,
                               AnalyticsParameter.count.rawValue: count
                           ])
        case .sensorRefused(let sensor):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorRefused.rawValue,
                           parameters: [AnalyticsParameter.sensor.rawValue: sensor])
        case .sensorDeepestWindow(let sensor, let windowDay):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorDeepestWindow.rawValue,
                           parameters: [
                               AnalyticsParameter.sensor.rawValue: sensor,
                               AnalyticsParameter.windowDay.rawValue: windowDay
                           ])
        case .sensorRecordDropped(let sensor, let count, let reason):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorRecordDropped.rawValue,
                           parameters: [
                               AnalyticsParameter.sensor.rawValue: sensor,
                               AnalyticsParameter.count.rawValue: count,
                               AnalyticsParameter.reason.rawValue: reason
                           ])
        case .sensorTimezoneFallback(let reason):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorTimezoneFallback.rawValue,
                           parameters: [AnalyticsParameter.reason.rawValue: reason])
        case .sensorFieldMissing(let sensor, let field, let missing, let total):
            self.sendEvent(withEventName: FirebaseEventCustomName.sensorFieldMissing.rawValue,
                           parameters: [
                               AnalyticsParameter.sensor.rawValue: sensor,
                               AnalyticsParameter.field.rawValue: field,
                               AnalyticsParameter.count.rawValue: missing,
                               AnalyticsParameter.total.rawValue: total
                           ])
        default:
            break
        }
    }

    // MARK: - FUAM-3021 watchdog event helpers

    private func permissionWatchdogTimeout(branch: String,
                                           previousBranch: String?,
                                           elapsedMs: Int,
                                           attempt: Int) {
        var parameters: [String: Any] = [
            AnalyticsParameter.branch.rawValue: branch,
            AnalyticsParameter.elapsedMs.rawValue: elapsedMs,
            AnalyticsParameter.attempt.rawValue: attempt
        ]
        if let previousBranch = previousBranch {
            parameters[AnalyticsParameter.previousBranch.rawValue] = previousBranch
        }
        self.sendEvent(withEventName: FirebaseEventCustomName.permissionWatchdogTimeout.rawValue,
                       parameters: parameters)
    }

    private func permissionWatchdogRetry(branch: String, attempt: Int) {
        self.sendEvent(withEventName: FirebaseEventCustomName.permissionWatchdogRetry.rawValue,
                       parameters: [
                           AnalyticsParameter.branch.rawValue: branch,
                           AnalyticsParameter.attempt.rawValue: attempt
                       ])
    }

    private func permissionWatchdogSkipped(branch: String, wasFirstAttempt: Bool) {
        self.sendEvent(withEventName: FirebaseEventCustomName.permissionWatchdogSkipped.rawValue,
                       parameters: [
                           AnalyticsParameter.branch.rawValue: branch,
                           AnalyticsParameter.wasFirstAttempt.rawValue: wasFirstAttempt
                       ])
    }

    // MARK: - FUAM-3844 sensor-data clearance mismatch

    private func sensorDataClearanceMismatch(reason: String, authorizedSensors: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.sensorDataClearanceMismatch.rawValue,
                       parameters: [
                           AnalyticsParameter.reason.rawValue: reason,
                           AnalyticsParameter.authorizedSensors.rawValue: authorizedSensors
                       ])
    }

    // MARK: - FUAM-3841 backfill reach

    private func sensorDataBackfillReach(sensor: String, reachedBack: String, boundedBy: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.sensorDataBackfillReach.rawValue,
                       parameters: [
                           AnalyticsParameter.sensor.rawValue: sensor,
                           AnalyticsParameter.reachedBack.rawValue: reachedBack,
                           AnalyticsParameter.boundedBy.rawValue: boundedBy
                       ])
    }

    // MARK: - FUAM-3945 forward clock jump

    private func sensorDataClockAhead(mark: String, deviceNow: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.sensorDataClockAhead.rawValue,
                       parameters: [
                           AnalyticsParameter.clockMark.rawValue: mark,
                           AnalyticsParameter.deviceNow.rawValue: deviceNow
                       ])
    }

    // MARK: - FUAM-3945 SensorKit recording start failure

    private func sensorRecordingStartFailed(sensor: String, error: String) {
        self.sendEvent(withEventName: FirebaseEventCustomName.sensorRecordingStartFailed.rawValue,
                       parameters: [
                           AnalyticsParameter.sensor.rawValue: sensor,
                           AnalyticsParameter.sensorError.rawValue: error
                       ])
    }

    // MARK: - FUAM-3945 SensorKit entitlement gap

    private func sensorEntitlementMissing(sensors: String, count: Int) {
        // F7: `sensors` arrives already capped at Firebase's 100-char string-parameter limit
        // (see `SensorKitEntitlement.droppedSensorsParameter`); `count` carries the cardinality
        // that survives any truncation.
        self.sendEvent(withEventName: FirebaseEventCustomName.sensorEntitlementMissing.rawValue,
                       parameters: [
                           AnalyticsParameter.droppedSensors.rawValue: sensors,
                           AnalyticsParameter.droppedCount.rawValue: count
                       ])
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
        guard let nsError = apiError.nsError else {
            return
        }
        self.reportNonFatalError(nsError)
    }
    
    func healthError(withHealthError healthError: HealthError) {
        guard let nsError = healthError.nsError else {
            return
        }
        self.reportNonFatalError(nsError)
    }
    
    // MARK: Screens
    
    private func sendRecordScreen(screenName: String, screenClass: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: screenName,
                                                                 AnalyticsParameterScreenClass: screenClass])
    }
    
    private func sendEvent(withEventName eventName: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(eventName, parameters: parameters)
    }
        
    private func reportNonFatalError(withDomain domain: FirebaseErrorDomain, statusCode: Int, userInfo: [String: Any]? = nil) {
        self.reportNonFatalError(NSError(domain: domain.stringValue, code: statusCode, userInfo: userInfo))
    }
    
    private func reportNonFatalError(_ nsError: NSError) {
        Crashlytics.crashlytics().record(error: nsError)
    }
}

extension ApiError {
    var nsError: NSError? {
        switch self {
        case .connectivity: return nil // Reachability errors won't be tracked
        case let .cannotParseData(pathUrl, request, statusCode, responseBody):
            return self.getNSError(forErrorType: "parse_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: statusCode,
                                   request: request,
                                   responseBody: responseBody)
        case let .network(pathUrl, request, underlyingError):
            return self.getNSError(forErrorType: "network_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: 502,
                                   request: request,
                                   underlyingError: underlyingError)
        case let .unexpectedError(pathUrl, request, statusCode, responseBody):
            return self.getNSError(forErrorType: "server_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: statusCode,
                                   request: request,
                                   responseBody: responseBody)
        case let .expectedError(pathUrl, request, statusCode, responseBody, _):
            return self.getNSError(forErrorType: "unhandled_error",
                                   domain: FirebaseErrorDomain.serverError(requestName: request.serviceRequest.requestName),
                                   pathUrl: pathUrl,
                                   statusCode: statusCode,
                                   request: request,
                                   responseBody: responseBody)
        case .userUnauthorized: return nil // User Unauthorized errors are expected and handled correctly by the app
        }
    }
    
    private func getNSError(forErrorType errorType: String,
                            domain: FirebaseErrorDomain,
                            pathUrl: String,
                            statusCode: Int,
                            request: ApiRequest,
                            responseBody: String? = nil,
                            underlyingError: Error? = nil) -> NSError {
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
        return NSError(domain: domain.stringValue, code: statusCode, userInfo: userInfo)
    }
}

extension HealthError {
    var nsError: NSError? {
        switch self {
        case .healthKitNotAvailable:
            return self.getNSError(forDomain: FirebaseErrorDomain.healthError(errorName: "health_kit_not_available_error"))
        case let .permissionRequestError(underlyingError):
            return self.getNSError(forDomain: FirebaseErrorDomain.healthError(errorName: "permission_request_error"),
                                   underlyingError: underlyingError)
        case let .getPermissionRequestStatusError(underlyingError):
            return self.getNSError(forDomain: FirebaseErrorDomain.healthError(errorName: "get_permission_request_status_error"),
                                   underlyingError: underlyingError)
        }
    }
    
    private func getNSError(forDomain domain: FirebaseErrorDomain, underlyingError: Error? = nil) -> NSError {
        var userInfo: [String: Any] = [:]
        if let underlyingError = underlyingError {
            userInfo[FirebaseErrorCustomUserInfo.healthUnderlyingError.rawValue] = underlyingError
        }
        return NSError(domain: domain.stringValue, code: 500, userInfo: userInfo)
    }
}
