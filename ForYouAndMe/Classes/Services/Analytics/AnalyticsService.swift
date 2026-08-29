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
    // FUAM-3021. Opt-in permission-chain watchdog attributes.
    case branch
    case previousBranch = "previous_branch"
    case elapsedMs = "elapsed_ms"
    case attempt
    case wasFirstAttempt = "was_first_attempt"
    // FUAM-3844. Sensor-data clearance mismatch attributes.
    case reason
    case authorizedSensors = "authorized_sensors"
    // FUAM-3841. Backfill-reach attributes.
    case sensor
    case reachedBack = "reached_back"
    case boundedBy = "bounded_by"
    // FUAM-3945 / FUAM-3964. Device-vs-server clock diagnostic attributes.
    case clockMark = "clock_mark"
    case deviceNow = "device_now"
    // FUAM-3945 round 7. SensorKit recording-start failure attributes.
    case sensorError = "error"
    // FUAM-3945 round 8. Sensors dropped because the host is not entitled to them.
    case droppedSensors = "dropped_sensors"
    // FUAM-3945 round 9 (D12/AC8). Windowing observability attributes.
    case device
    case windowDay = "window_day"
    case pass
    case ageDays = "age_days"
    case novelCount = "novel_count"
    case count
    case spanSeconds = "span_s"
    case droppedCount = "dropped_count"
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
    case spyrometerComplete = "SpyroMeterComplete"
    case consentName = "ConsentName"
    case consentSignature = "ConsentSignature"
    case openPermissions = "Permissions"
    case openAppsAndDevices = "AppsAndDevices"
    case openPreferences = "Preferences"
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

    // FUAM-3021. Opt-in permission-chain watchdog (Approach B from FUAM-3020).
    // These cases are emitted via AnalyticsServiceSink (which bridges from
    // Telemetry events) — not called directly from application code.
    case permissionWatchdogTimeout(branch: String, previousBranch: String?, elapsedMs: Int, attempt: Int)
    case permissionWatchdogRetry(branch: String, attempt: Int)
    case permissionWatchdogSkipped(branch: String, wasFirstAttempt: Bool)

    // FUAM-3844. Emitted when sensor-data clearance is false while at least one configured
    // SensorKit sensor is OS-authorized — that combination is always a bug (see FUAM-3835).
    case sensorDataClearanceMismatch(reason: String, authorizedSensors: String)

    // FUAM-3841 / FUAM-3945. Emitted when a backfill opens: how far back the client actually
    // reached for a sensor (ISO8601) and what bounded it, so the study team can tell "the OS
    // deleted it" from "the client never asked". `boundedBy` is a
    // `BackfillLowerBound.Origin.rawValue`: "join_date", "hard_cap_365d", "forward_only",
    // "empty_plan", "gave_up", "drain_filtered", "bisected", "attempts_exhausted" or
    // "future_cursor" (a cursor burnt into the future by a clock excursion was reset to the
    // consent bound; `reachedBack` is then the corrupt cursor, so the recovered gap is readable).
    // ("enrollment" and "retention_floor" are superseded.) The
    // `cursor` origin is carried in the plan but deliberately never emitted: a routine cursor
    // resume is not a backfill and would drown the actionable events.
    // One exception to the closed vocabulary: the HealthKit "unrecognised upload error" path
    // emits "gave_up:<error domain>#<code>" — the same class of event (the sequence moved on
    // without advancing), with the only diagnostic that makes it actionable attached.
    case sensorDataBackfillReach(sensor: String, reachedBack: String, boundedBy: String)

    // FUAM-3945 / FUAM-3964. Emitted once per launch when the device clock is more than a day
    // away from the server's (the offset learnt from the `Date` response header, see
    // `ServerClock`). `mark` is server time, `deviceNow` is device time, both ISO8601, so the
    // signed drift is (mark - deviceNow) — positive when the device is behind. The event name is
    // kept from the superseded `BackfillClock` diagnostic it replaces; the parameters now mean
    // device-vs-server rather than device-vs-high-water-mark.
    case sensorDataClockAhead(mark: String, deviceNow: String)

    // FUAM-3945 round 7. A SensorKit reader's `startRecording()` failed: that sensor records
    // nothing until the next successful start, and without this event the silence is
    // indistinguishable from a participant with no data. Once per sensor per launch. `error` is
    // the NSError domain/code — never the localized description (locale-dependent, unaggregatable).
    case sensorRecordingStartFailed(sensor: String, error: String)

    // FUAM-3945 round 8. The host's declared SensorKit entitlement does not cover every sensor
    // the SDK is configured to collect, so those sensors were dropped from the requested set. iOS
    // would never have prompted for them anyway (it auto-declines instantly and leaves them
    // `.notDetermined` forever) — this event is what makes the host misconfiguration visible
    // instead of silent. Emitted once per launch, at service setup; `sensors` is the
    // comma-joined, sorted list of dropped sensor subsources, CAPPED at Firebase's 100-char
    // string-parameter limit (F7), with `count` carrying the true cardinality.
    case sensorEntitlementMissing(sensors: String, count: Int)

    // FUAM-3945 round 9 (D12/AC8) — the windowing observability set. These are what make the
    // D-C/D-D class of production data loss findable in Firebase instead of by hand-diffing
    // production tables.

    // A window the OS answered successfully with ZERO records. `pass` is "first" for a window at
    // the head of the walk and "rescan_N" (N = age of the window's day, in days) for a rescan
    // re-read: a report sensor empty on first pass AND every rescan is a windowing bug.
    case sensorWindowEmpty(sensor: String, device: String, windowDay: String, pass: String)
    // A rescan pass found records the ledger had never seen: the field measurement of SensorKit's
    // write lag (D-D). `ageDays` buckets the completion curve that tunes the rescan depth R.
    case sensorRescanNovel(sensor: String, device: String, ageDays: Int, novelCount: Int)
    // An `SRDeletionRecord` observed during a rescan pass: the gap is permanent and the OS named
    // the reason — as opposed to a gap that may still fill on a later rescan (S10).
    case sensorDeletionRecord(sensor: String, reason: String, spanSeconds: Int)
    // A record whose fingerprint is new but whose measurement period overlaps one already in the
    // upload ledger: SensorKit re-fetch boundary drift (S7), measured — never prevented (D13).
    case sensorNearDuplicate(sensor: String, count: Int)
    // iOS refused to draw the authorization prompt for a sensor that was asked (fast auto-decline
    // outside a master-switch-off round): the empirical entitlement fallback firing (D6).
    case sensorRefused(sensor: String)
    // The deepest (oldest) window that ever returned data for a sensor+device: the MEASURED OS
    // retention (AC1), so the real horizon is a number, not an assumption.
    case sensorDeepestWindow(sensor: String, windowDay: String)
    // Records dropped client-side before upload (consent gate, unreadable measurement time):
    // deliberate, but never silent (AC6).
    case sensorRecordDropped(sensor: String, count: Int, reason: String)
    // The window/batch partition fell back to UTC because no backend-authoritative
    // `user.time_zone` was available (AC2 revised): the partition may not match the adherence
    // chart's bucketing until the user record loads. Once per launch.
    case sensorTimezoneFallback(reason: String)

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
        case .getTerraToken: return "Get Terra Token"
        // Onboarding Section
        case .submitProfilingOption: return "Onboarding Section"
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
        case .createOtherUserConsent: return "Create Other User Content"
        case .updateUserConsent: return "Update User Consent"
        case .notifyOnboardingCompleted: return "Notify User Consent Completed"
        case .verifyEmail: return "Confirm Email"
        case .resendConfirmationEmail: return "Resend Confirmation Email"
        case .getOnboardingQuestionsSection: return "Onboarding Questions"
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
        case .sendSkipTask: return "Skip Task"
        case .delayTask: return "Reschedule Task"
        case .sendSpyroResults: return "Spyro Task"
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
        case .sendMenstrualUserSettings: return "Send Menstrual User Settings"
        case .getDiaryNotes: return "Get Diary Notes"
        case .getDiaryNoteText: return "Get Diary Note Text"
        case .getDiaryNoteAudio: return "Get Diary Note Audio"
        case .getMenstrualDiaryNote: return "Get Menstrual Diary Note"
        case .sendDiaryNoteText: return "Send Diary Note Text"
        case .sendDiaryNoteAudio: return "Send Diary Note Audio"
        case .sendDiaryNoteVideo: return "Send Diary Note Video"
        case .sendDiaryNoteEaten: return "Send Diary Note Eaten"
        case .sendDiaryNoteMenstrual: return "Send Diary Note Menstrual"
        case .sendDiaryNoteDoses: return "Send Diary Note Doses"
        case .sendCombinedDiaryNote: return "Send We Have Noticed Diary Note"
        case .sendDiaryNoteHotFlash: return "Send Diary Note Hot Flash"
        case .deleteDiaryNote: return "Delete Diary Note"
        case .updateDiaryNoteText: return "Update Diary Note Text"
        // Survey
        case .getSurvey: return "Get Survey"
        case .sendSurveyTaskResultData: return "Send Survey Task Result Data"
        // Device Data
        case .sendDeviceData: return "Send Phone Events"
        // Health
        case .sendHealthData: return "Send Health Data"
        case .sendSensorKitData: return "Send SensorKit Data"
        // Phase
        case .createUserPhase: return "Create User Phase"
        case .updateUserPhase: return "Update User Phase"
        case .getInfoMessages: return "Get Info Messages"
        }
    }
}
