//
//  AnalyticsService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

enum AnalyticsParameter: String {
    case userId
    case start
    case pause
    case close
    case screenId = "screen_id"
    case questionId = "question_id"
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

enum AnalyticsScreens: String {
    case intro = "Intro"
    case getStarted = "GetStarted"
    case setupLater = "SetupLater"
    case requestSetUp = "RequestAccountSetup"
    case userRegistration = "UserRegistration"
    case otpValidation = "ValidateOTP"
    case studyVideo = "StudyVideo"
    case videoDiary = "VideoDiary"
    case aboutYou = "About You"
    case videoDiaryComplete = "VideoDiaryComplete"
    case consentName = "ConsentName"
    case consentSignature = "ConsentSignature"
    case openPermissions = "Permissions"
    case openAppsAndDevices = "AppsAndDevices"
    case emailInsert = "Email"
    case emailVerification = "EmailVerification"
    case oAuth = "OAuth"
    //    case faq = "FAQ"
    //    case contact = "Contact"
    //    case points = "Points"
    case browser = "Browser"
    case learnMore = "LearnMore"
    case feed = "Feed"
    case task = "Task"
    case yourData = "YourData"
    case yourDataFilter = "YourDataFilter"
    case studyInfo = "StudyInfo"
    case privacyPolicy = "PrivacyPolicy"
    case termsOfService = "TermsOfService"
}

enum AnalyticsEvent {
    // Screening
    case screeningQuizCompleted(answers: [Answer])
    // Informed Consent
    case informedConsentQuizCompleted(answers: [Answer])
    // Record Page
    case recordScreen(screenName: String, screenClass: String)
    // User
    case setUserID(_ userID: String)
    case setUserPropertyString(_ value: String?, forName: String)
    case userRegistration(_ accountType: String)
    
    // Onboarding
    case startStudyAction(_ actionType: String)
    case cancelDuringScreeningQuestion(_ questionID: String?)
    case cancelDuringInformedConsent(_ pageID: String)
    case cancelDuringComprehensionQuiz(_ questionID: String)
    case consentAgreed
    case consentDisagreed
    
    // Main App
    case switchTab(_ tabName: String)
    case quickActivity(_ quickActivityID: String, option: String)
    case yourDataSelectionPeriod(_ period: String)
    
    // Task
    case videoDiaryAction(_ action: String)
    
    // Permission
    case locationPermissionChanged(_ status: String)
    case notificationPermissionChanged(_ status: String)
    
    // Errors
    case serverError(apiError: ApiError)
    case healthError(healthError: HealthError)
}

protocol AnalyticsService {
    func track(event: AnalyticsEvent)
}

extension DefaultService {
    var requestName: String {
        switch self {
        case .getGlobalConfig: return "Get Configuration"
        case .getStudy: return "Get Study"
        // Login
        case .submitPhoneNumber: return "Verify Phone Number"
        case .verifyPhoneNumber: return "Login"
        case .emailLogin: return "Email Login"
        // Screening Section
        case .getScreeningSection: return "Get Screening"
        // Informed Consent Section
        case .getInformedConsentSection: return "Get Informed Consent"
        // Consent Section
        case .getConsentSection: return "Get Consent"
        // Opt In Section
        case .getOptInSection: return "Get Opt In"
        case .sendOptInPermission: return "Send User Permission"
        // User Consent Section
        case .getUserConsentSection: return "Get Signature"
        case .createUserConsent: return "Create User Consent"
        case .updateUserConsent: return "Update User Consent"
        case .notifyOnboardingCompleted: return "Notify User Consent Completed"
        case .verifyEmail: return "Confirm Email"
        case .resendConfirmationEmail: return "Resend Confirmation Email"
        // Study Info Section
        case .getStudyInfoSection: return "Get Study Info"
        // Integration Section
        case .getIntegrationSection: return "Get Integration"
        // Answer
        case .sendAnswer: return "Send Answer"
        // Feed
        case .getFeeds: return "Get Feeds"
        // Task
        case .getTasks: return "Get Tasks"
        case .getTask: return "Get Task"
        case .sendTaskResultData: return "Send Task Result Data"
        case .sendTaskResultFile: return "Send Task Result Attachment"
        case .delayTask: return "Reschedule Task"
        // User
        case .getUser: return "Get User"
        case .sendUserInfoParameters: return "Send User Info Parameters"
        case .sendUserTimeZone: return "Send User Device Time Zone"
        case .sendPushToken: return "Add Firebase Token"
        case .sendWalthroughDone: return "Walkthrough Done"
        // User Data
        case .getUserData: return "Get Your Data"
        case .getUserSettings: return "Get User Settings"
        case .sendUserSettings: return "Send User Settings"
        case .getDiaryNotes: return "Get Diary Notes"
        case .getDiaryNoteText: return "Get Diary Note Text"
        case .getDiaryNoteAudio: return "Get Diary Note Audio"
        case .sendDiaryNoteText: return "Send Diary Note Text"
        case .sendDiaryNoteAudio: return "Send Diary Note Audio"
        case .sendDiaryNoteVideo: return "Send Diary Note Video"
        case .deleteDiaryNote: return "Delete Diary Note"
        case .updateDiaryNoteText: return "Update Diary Note Text"
        // Survey
        case .getSurvey: return "Get Survey"
        case .sendSurveyTaskResultData: return "Send Survey Task Result Data"
        // Device Data
        case .sendDeviceData: return "Send Phone Events"
        // Health
        case .sendHealthData: return "Send Health Data"
        // Phase
        case .createUserPhase: return "Create User Phase"
        case .updateUserPhase: return "Update User Phase"
        case .getInfoMessages: return "Get Info Messages"
        }
    }
}
