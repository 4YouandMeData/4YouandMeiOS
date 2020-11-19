//
//  StringsProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

typealias StringMap = [StringKey: String]

enum StringKey: String, CaseIterable, CodingKey {
    // Setup
    case setupErrorTitle = "SETUP_ERROR_TITLE"
    // Welcome
    case welcomeStartButton = "WELCOME_START_BUTTON"
    // Intro
    case introTitle = "INTRO_TITLE"
    case introBody = "INTRO_BODY"
    case introLogin = "INTRO_LOGIN"
    case introSetupLater = "INTRO_BACK"
    // Setup Later
    case setupLaterBody = "SETUP_LATER_BODY"
    case setupLaterConfirmButton = "SETUP_LATER_CONFIRM_BUTTON"
    // Phone Verification
    case phoneVerificationTitle = "PHONE_VERIFICATION_TITLE"
    case phoneVerificationBody = "PHONE_VERIFICATION_BODY"
    case phoneVerificationNumberDescription = "PHONE_VERIFICATION_NUMBER_DESCRIPTION"
    case phoneVerificationCountryPickerTitle = "PHONE_VERIFICATION_COUNTRY_PICKER_TITLE"
    case phoneVerificationLegal = "PHONE_VERIFICATION_LEGAL"
    case phoneVerificationLegalTermsOfService = "PHONE_VERIFICATION_LEGAL_TERMS_OF_SERVICE"
    case phoneVerificationLegalPrivacyPolicy = "PHONE_VERIFICATION_LEGAL_PRIVACY_POLICY"
    case phoneVerificationWrongNumber = "PHONE_VERIFICATION_WRONG_NUMBER"
    case phoneVerificationCodeTitle = "PHONE_VERIFICATION_CODE_TITLE"
    case phoneVerificationCodeBody = "PHONE_VERIFICATION_CODE_BODY"
    case phoneVerificationCodeDescription = "PHONE_VERIFICATION_CODE_DESCRIPTION"
    case phoneVerificationCodeResend = "PHONE_VERIFICATION_CODE_RESEND"
    case phoneVerificationErrorWrongCode = "PHONE_VERIFICATION_ERROR_WRONG_CODE"
    case phoneVerificationErrorMissingNumber = "PHONE_VERIFICATION_ERROR_MISSING_NUMBER"
    // Setup Later
    case introVideoContinueButton = "INTRO_VIDEO_CONTINUE_BUTTON"
    // Onboarding
    case onboardingSectionList = "ONBOARDING_SECTION_LIST"
    case onboardingAbortButton = "ONBOARDING_ABORT_BUTTON"
    case onboardingAbortTitle = "ONBOARDING_ABORT_TITLE"
    case onboardingAbortMessage = "ONBOARDING_ABORT_MESSAGE"
    case onboardingAbortConfirm = "ONBOARDING_ABORT_CONFIRM"
    case onboardingAbortCancel = "ONBOARDING_ABORT_CANCEL"
    case onboardingAgreeButton = "ONBOARDING_AGREE_BUTTON"
    case onboardingDisagreeButton = "ONBOARDING_DISAGREE_BUTTON"
    case onboardingOptInMandatoryClose = "ONBOARDING_OPT_IN_MANDATORY_CLOSE"
    case onboardingOptInMandatoryTitle = "ONBOARDING_OPT_IN_MANDATORY_TITLE"
    case onboardingOptInMandatoryDefault = "ONBOARDING_OPT_IN_MANDATORY_DEFAULT"
    case onboardingOptInSubmitButton = "ONBOARDING_OPT_IN_SUBMIT_BUTTON"
    case onboardingUserNameTitle = "ONBOARDING_USER_NAME_TITLE"
    case onboardingUserNameFirstNameDescription = "ONBOARDING_USER_NAME_FIRST_NAME_DESCRIPTION"
    case onboardingUserNameLastNameDescription = "ONBOARDING_USER_NAME_LAST_NAME_DESCRIPTION"
    case onboardingUserEmailEmailDescription = "ONBOARDING_USER_EMAIL_EMAIL_DESCRIPTION"
    case onboardingUserEmailInfo = "ONBOARDING_USER_EMAIL_INFO"
    case onboardingUserEmailVerificationTitle = "ONBOARDING_USER_EMAIL_VERIFICATION_TITLE"
    case onboardingUserEmailVerificationBody = "ONBOARDING_USER_EMAIL_VERIFICATION_BODY"
    case onboardingUserEmailVerificationWrongEmail
        = "ONBOARDING_USER_EMAIL_VERIFICATION_WRONG_EMAIL"
    case onboardingUserEmailVerificationCodeDescription
        = "ONBOARDING_USER_EMAIL_VERIFICATION_CODE_DESCRIPTION"
    case onboardingUserEmailVerificationErrorWrongCode
        = "ONBOARDING_USER_EMAIL_VERIFICATION_ERROR_WRONG_CODE"
    case onboardingUserEmailVerificationResend = "ONBOARDING_USER_EMAIL_VERIFICATION_RESEND"
    case onboardingUserSignatureTitle = "ONBOARDING_USER_SIGNATURE_TITLE"
    case onboardingUserSignatureBody = "ONBOARDING_USER_SIGNATURE_BODY"
    case onboardingUserSignaturePlaceholder = "ONBOARDING_USER_SIGNATURE_PLACEHOLDER"
    case onboardingUserSignatureClear = "ONBOARDING_USER_SIGNATURE_CLEAR"
    case onboardingIntegrationNextButtonDefault = "ONBOARDING_WEARABLES_NEXT_BUTTON_DEFAULT"
    case onboardingIntegrationDownloadButtonDefault = "ONBOARDING_WEARABLES_DOWNLOAD_BUTTON_DEFAULT"
    case onboardingIntegrationOpenAppButtonDefault = "ONBOARDING_WEARABLES_OPEN_APP_BUTTON_DEFAULT"
    case onboardingIntegrationLoginButtonDefault = "ONBOARDING_WEARABLES_LOGIN_BUTTON_DEFAULT"
    // Main
    case tabFeed = "TAB_FEED"
    case tabTask = "TAB_TASK"
    case tabUserData = "TAB_USER_DATA"
    case tabStudyInfo = "TAB_STUDY_INFO"
    case tabFeedTitle = "TAB_FEED_TITLE"
    case tabFeedSubtitle = "TAB_FEED_SUBTITLE"
    case tabTaskTitle = "TAB_TASK_TITLE"
    case tabUserDataTitle = "TAB_USER_DATA_TITLE"
    case tabUserDataPeriodDay = "TAB_USER_DATA_PERIOD_DAY"
    case tabUserDataPeriodWeek = "TAB_USER_DATA_PERIOD_WEEK"
    case tabUserDataPeriodMonth = "TAB_USER_DATA_PERIOD_MONTH"
    case tabUserDataPeriodYear = "TAB_USER_DATA_PERIOD_YEAR"
    case tabUserDataAggregationErrorTitle = "TAB_USER_DATA_AGGREGATION_ERROR_TITLE"
    case tabUserDataAggregationErrorBody = "TAB_USER_DATA_AGGREGATION_ERROR_BODY"
    case tabUserDataAggregationErrorButton = "TAB_USER_DATA_AGGREGATION_ERROR_BUTTON"
    case tabStudyInfoTitle = "TAB_STUDY_INFO_TITLE"
    case tabFeedEmptyTitle = "TAB_FEED_EMPTY_TITLE"
    case tabFeedEmptySubtitle = "TAB_FEED_EMPTY_SUBTITLE"
    case tabTaskEmptyTitle = "TAB_TASK_EMPTY_TITLE"
    case tabTaskEmptySubtitle = "TAB_TASK_EMPTY_SUBTITLE"
    case tabTaskEmptyButton = "TAB_TASK_EMPTY_BUTTON"
    case tabUserDataPeriodTitle = "TAB_USER_DATA_PERIOD_TITLE"
    case tabFeedHeaderTitle = "TAB_FEED_HEADER_TITLE"
    case tabFeedHeaderSubtitle = "TAB_FEED_HEADER_SUBTITLE"
    case tabFeedHeaderPoints = "TAB_FEED_HEADER_POINTS"
    case profileTitle = "PROFILE_TITLE"
    // Task
    case taskStartButton = "TASK_START_BUTTON"
    case taskRemindMeLater = "TASK_REMIND_ME_LATER"
    // Activity
    case activityButtonDefault = "ACTIVITY_BUTTON_DEFAULT"
    // Quick Activity
    case quickActivityButtonDefault = "QUICK_ACTIVITY_BUTTON_DEFAULT"
    // Notifiable
    case educationalButtonDefault = "EDUCATIONAL_BUTTON_DEFAULT"
    case rewardButtonDefault = "REWARD_BUTTON_DEFAULT"
    case alertButtonDefault = "ALERT_BUTTON_DEFAULT"
    // Survey
    case surveyButtonDefault = "SURVEY_BUTTON_DEFAULT"
    case surveyButtonSkip = "SURVEY_BUTTON_SKIP"
    case surveyStepsCount = "SURVEY_STEPS_COUNT"
    // Video Diary
    case videoDiaryRecorderTitle = "VIDEO_DIARY_RECORDER_TITLE"
    case videoDiaryRecorderStartRecordingDescription = "VIDEO_DIARY_RECORDER_START_RECORDING_DESCRIPTION"
    case videoDiaryRecorderResumeRecordingDescription = "VIDEO_DIARY_RECORDER_RESUME_RECORDING_DESCRIPTION"
    case videoDiaryRecorderInfoTitle = "VIDEO_DIARY_RECORDER_INFO_TITLE"
    case videoDiaryRecorderInfoBody = "VIDEO_DIARY_RECORDER_INFO_BODY"
    case videoDiaryRecorderReviewButton = "VIDEO_DIARY_RECORDER_REVIEW_BUTTON"
    case videoDiaryRecorderSubmitButton = "VIDEO_DIARY_RECORDER_SUBMIT_BUTTON"
    case videoDiaryRecorderSubmitFeedback = "VIDEO_DIARY_RECORDER_SUBMIT_FEEDBACK"
    case videoDiaryRecorderCloseButton = "VIDEO_DIARY_RECORDER_CLOSE_BUTTON"
    case videoDiaryDiscardTitle = "VIDEO_DIARY_DISCARD_TITLE"
    case videoDiaryDiscardBody = "VIDEO_DIARY_DISCARD_BODY"
    case videoDiaryDiscardConfirm = "VIDEO_DIARY_DISCARD_CONFIRM"
    case videoDiaryDiscardCancel = "VIDEO_DIARY_DISCARD_CANCEL"
    case videoDiaryMissingPermissionTitleCamera = "VIDEO_DIARY_MISSING_PERMISSION_TITLE_CAMERA"
    case videoDiaryMissingPermissionTitleMic = "VIDEO_DIARY_MISSING_PERMISSION_TITLE_MIC"
    case videoDiaryMissingPermissionBodyCamera = "VIDEO_DIARY_MISSING_PERMISSION_BODY_CAMERA"
    case videoDiaryMissingPermissionBodyMic = "VIDEO_DIARY_MISSING_PERMISSION_BODY_MIC"
    case videoDiaryMissingPermissionSettings = "VIDEO_DIARY_MISSING_PERMISSION_SETTINGS"
    case videoDiaryMissingPermissionDiscard = "VIDEO_DIARY_MISSING_PERMISSION_DISCARD"

    //Study Info
    case studyInfoContactTitle = "STUDY_INFO_CONTACT_INFO"
    case studyInfoRewardsTitle = "STUDY_INFO_REWARDS"
    case studyInfoFaqTitle = "STUDY_INFO_FAQ"
    case studyInfoAboutYou = "STUDY_INFO_ABOUT_YOU"
    //About You
    case aboutYouUserInfo = "ABOUT_YOU_YOUR_PREGNANCY"
    case aboutYouAppsAndDevices = "ABOUT_YOU_APPS_AND_DEVICES"
    case aboutYouReviewConsent = "ABOUT_YOU_REVIEW_CONSENT"
    case aboutYouPermissions = "ABOUT_YOU_PERMISSIONS"
    case disclaimerFooter = "ABOUT_YOU_DISCLAIMER"
    //User Info
    case userInfoButtonEdit = "PROFILE_USER_INFO_BUTTON_EDIT"
    case userInfoButtonSubmit = "PROFILE_USER_INFO_BUTTON_SUBMIT"
    // Permissions
    case permissionDeniedTitle = "PERMISSION_DENIED"
    case permissionSettings = "PERMISSION_SETTINGS"
    case permissionCancel = "PERMISSION_CANCEL"
    case permissionMessage = "PERMISSION_MESSAGE"
    case allowMessage = "PERMISSIONS_ALLOW"
    case allowedMessage = "PERMISSIONS_ALLOWED"
    case connectMessage = "YOUR_APPS_AND_DEVICES_CONNECT"
    
    // Generic
    case genericInfoTitle = "GENERIC_INFO_TITLE"
    // Errors
    case errorTitleDefault = "ERROR_TITLE_DEFAULT"
    case errorButtonCancel = "ERROR_BUTTON_CANCEL"
    case errorButtonRetry = "ERROR_BUTTON_RETRY"
    case errorButtonClose = "ERROR_BUTTON_CLOSE"
    case errorMessageDefault = "ERROR_MESSAGE_DEFAULT"
    case errorMessageRemoteServer = "ERROR_MESSAGE_REMOTE_SERVER"
    case errorMessageConnectivity = "ERROR_MESSAGE_CONNECTIVITY"
    // Urls
    case urlPrivacyPolicy = "URL_PRIVACY_POLICY"
    case urlTermsOfService = "URL_TERMS_OF_SERVICE"
    
    //OAUTH
    case ouraOauthTitle = "OAUTH_OURA"
    case fitbitOauthTitle = "OAUTH_FITBIT"
    case garminOauthTitle = "OAUTH_GARMIN"
    case twitterOauthTitle = "OAUTH_TWITTER"
    case instagramOauthTitle = "OAUTH_INSTAGRAM"
    case rescueTimeOauthTitle = "OAUTH_RESCUETIME"
    
    var defaultValue: String {
        switch self {
        case .setupErrorTitle: return "Uh, oh!"
        case .genericInfoTitle: return "Info"
        case .errorTitleDefault: return "Error"
        case .errorButtonCancel: return "Cancel"
        case .errorButtonRetry: return "Try again"
        case .errorButtonClose: return "Ok"
        case .errorMessageDefault: return "Something went wrong,\nplease try again"
        case .errorMessageRemoteServer: return "Something went wrong,\nplease try again"
        case .errorMessageConnectivity: return "You seem to be offline.\nPlease check your internet connection and try again."
        default: return ""
        }
    }
}

class StringsProvider {
    
    private static var stringMap: StringMap = [:]
    
    static func initialize(withStringMap stringMap: StringMap) {
        self.stringMap = stringMap
    }
    
    static func string(forKey key: StringKey, withParameters parameters: [String] = []) -> String {
        let string = self.stringMap[key] ?? key.defaultValue
        var formattedString = string
        for (index, element) in parameters.enumerated() {
            formattedString = formattedString.replacingOccurrences(of: "{\(index)}", with: element)
        }
        return formattedString
    }
}
