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
    case studyInfo = "StudyInfo"
    case privacyPolicy = "PrivacyPolicy"
    case termsOfService = "TermsOfService"
}

enum AnalyticsEvent {
    // Screening
    case screeningQuizCompleted(answers: [Answer])
    // Informed Consent
    case informedConsentQuizCompleted(answers: [Answer])
    //Record Page
    case recordScreen(screenName: String, screenClass: String)
    // User
    case setUserID(_ userID: String)
    case setUserPropertyString(_ value: String?, forName: String)
    case userRegistration(_ accountType: String)
    
    //Onboarding
    case startStudyAction(_ actionType: String)
    case cancelDuringScreeningQuestion(_ questionID: String?)
    case cancelDuringInformedConsent(_ pageID: String)
    case cancelDuringComprehensionQuiz(_ questionID: String)
    case consentAgreed
    case consentDisagreed
    
    //Main App
    case switchTab(_ tabName: String)
    case quickActivity(_ quickActivityID: String, option: String)
    case yourDataSelectionPeriod(_ period: String)
    
    //Permission
    case locationPermissionChanged(_ status: String)
    case notificationPermissionChanged(_ status: String)
}

protocol AnalyticsService {
    func track(event: AnalyticsEvent)
}
