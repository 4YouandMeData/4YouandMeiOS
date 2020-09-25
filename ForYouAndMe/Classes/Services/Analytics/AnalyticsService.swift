//
//  AnalyticsService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

enum AnalyticsScreens: String {
    case intro = "Intro"
    case getStarted = "GetStarted"
    case setupLater = "SetupLater"
    case requestSetUp = "RequestAccountSetup"
    case userRegistration = "UserRegistration"
    case userInfo = "UserInfo"
    case otpValidation = "ValidateOTP"
    case studyVideo = "StudyVideo"
    case videoDiary = "VideoDiary"
    case videoDiaryComplete = "VideoDiaryComplete"
    case consentName = "ConsentName"
    case consentSignature = "ConsentSignature"
    case openPermissions = "Permissions"
    case openAppsAndDevices = "AppsAndDevices"
    case profilePage = "Profile"
    case emailInsert = "Email"
    case emailVerification = "EmailVerification"
    case oAuth = "OAuth"
    case faq = "FAQ"
    case contact = "Contact"
    case points = "Points"
    case browser = "Browser"
    case learnMore = "LearnMore"
    case feed = "Feed"
    case task = "Task"
    case yourData = "YourData"
    case studyInfo = "StudyInfo"
    case privacyPolicy = "PrivacyPolicy"
    case termsOfService = "TermsOfService"
    case aboutYou = "About You"
}

enum AnalyticsEvent {
    // Screening
    case screeningQuizCompleted(answers: [Answer])
    // Informed Consent
    case informedConsentQuizCompleted(answers: [Answer])
    //Record Page
    case recordScreen(screenName: String, screenClass: String)
}

protocol AnalyticsService {
    func track(event: AnalyticsEvent)
}
