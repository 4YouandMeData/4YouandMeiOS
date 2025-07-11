//
//  StringsProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

typealias RequiredStringMap = [StringKey: String]
typealias FullStringMap = [String: String]

enum StringKey: String, CaseIterable, CodingKey {
    // Setup
    case setupErrorTitle = "SETUP_ERROR_TITLE"
    case tabBarList = "TAB_BAR_LIST"
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
    case onboardingSectionGroupList = "ONBOARDING_SECTION_LIST"
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
    case onboardingUserNameMinorTitle = "ONBOARDING_USER_NAME_MINOR_TITLE"
    case onboardingUserNameGuardianTitle = "ONBOARDING_USER_NAME_GUARDIAN_TITLE"
    case onboardingUserNameBody = "ONBOARDING_USER_NAME_BODY"
    case onboardingUserNameMinorBody = "ONBOARDING_USER_NAME_MINOR_BODY"
    case onboardingUserNameGuardianBody = "ONBOARDING_USER_NAME_GUARDIAN_BODY"
    case onboardingMinorTag = "ONBOARDING_USER_ADDITIONAL_SIGNATURE_MINOR_TAG"
    case onboardingUserNameFirstNameDescription = "ONBOARDING_USER_NAME_FIRST_NAME_DESCRIPTION"
    case onboardingUserNameLastNameDescription = "ONBOARDING_USER_NAME_LAST_NAME_DESCRIPTION"
    case onboardingUserNameRelatedDescription = "ONBOARDING_USER_NAME_RELATED_DESCRIPTION"
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
    case onboardingUserMinorSignatureTitle = "ONBOARDING_USER_MINOR_SIGNATURE_TITLE"
    case onboardingUserGuardianSignatureTitle = "ONBOARDING_USER_GUARDIAN_SIGNATURE_TITLE"
    case onboardingUserSignatureBody = "ONBOARDING_USER_SIGNATURE_BODY"
    case onboardingUserMinorSignatureBody = "ONBOARDING_USER_MINOR_SIGNATURE_BODY"
    case onboardingUserGuardianSignatureBody = "ONBOARDING_USER_GUARDIAN_SIGNATURE_BODY"
    case onboardingUserSignaturePlaceholder = "ONBOARDING_USER_SIGNATURE_PLACEHOLDER"
    case onboardingUserSignatureClear = "ONBOARDING_USER_SIGNATURE_CLEAR"
    case onboardingIntegrationNextButtonDefault = "ONBOARDING_WEARABLES_NEXT_BUTTON_DEFAULT"
    case onboardingIntegrationDownloadButtonDefault = "ONBOARDING_WEARABLES_DOWNLOAD_BUTTON_DEFAULT"
    case onboardingIntegrationOpenAppButtonDefault = "ONBOARDING_WEARABLES_OPEN_APP_BUTTON_DEFAULT"
    case onboardingIntegrationLoginButtonDefault = "ONBOARDING_WEARABLES_LOGIN_BUTTON_DEFAULT"
    // Main
    case tabFeed = "TAB_FEED"
    case tabTask = "TAB_TASK"
    case tabDiary = "TAB_DIARY"
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
    case tabUserDataEmptyFilterMessage = "TAB_USER_DATA_EMPTY_FILTER_MESSAGE"
    case tabUserDataEmptyFilterButton = "TAB_USER_DATA_EMPTY_FILTER_BUTTON"
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
    case fabElements = "FAB_ELEMENTS"
    
    // User Data Filter
    case userDataFilterTitle = "USER_DATA_FILTER_TITLE"
    case userDataFilterClearButton = "USER_DATA_FILTER_CLEAR_BUTTON"
    case userDataFilterSelectAllButton = "USER_DATA_FILTER_SELECT_ALL_BUTTON"
    case userDataFilterSaveButton = "USER_DATA_FILTER_SAVE_BUTTON"
    // Task
    case taskStartButton = "TASK_START_BUTTON"
    case taskRemindMeLater = "TASK_REMIND_ME_LATER"
    case placeholderOtherField = "OTHER_ANSWER_PLACEHOLDER"
    // Activity
    case activityButtonDefault = "ACTIVITY_BUTTON_DEFAULT"
    case skipActivityButtonDefault = "SKIP_ACTIVITY_BUTTON_DEFAULT"
    
    // Quick Activity
    case quickActivityButtonDefault = "QUICK_ACTIVITY_BUTTON_DEFAULT"
    case quickActivityButtonNext = "QUICK_ACTIVITY_BUTTON_NEXT"
    case quickActivityTotalNumber = "QUICK_ACTIVITIES_TOTAL_NUMBER"
    case quickActivitiesRemaining = "QUICK_ACTIVITIES_REMAINING"
    // Notifiable
    case educationalButtonDefault = "EDUCATIONAL_BUTTON_DEFAULT"
    case rewardButtonDefault = "REWARD_BUTTON_DEFAULT"
    case alertButtonDefault = "ALERT_BUTTON_DEFAULT"
    // Survey
    case surveyButtonDefault = "SURVEY_BUTTON_DEFAULT"
    case surveyButtonSkip = "SURVEY_BUTTON_SKIP"
    case surveyStepsCount = "SURVEY_STEPS_COUNT"
    case resetDots = "RESET_DOTS"
    case surveyButtonAbort = "SURVEY_BUTTON_ABORT"
    case surveyAbortTitle = "SURVEY_ABORT_TITLE"
    case surveyAbortMessage = "SURVEY_ABORT_MESSAGE"
    case surveyAbortCancel = "SURVEY_ABORT_CANCEL"
    case surveyAbortConfirm = "SURVEY_ABORT_CONFIRM"
    
    // Walkthrough
    case walkthroughButtonSkip = "WALKTHROUGH_BUTTON_SKIP"
    
    // Diary Note
    case diaryNoteTitle = "DIARY_NOTE_TITLE_DEFAULT"
    case diaryNoteRecordVideo = "DIARYNOTE_CREATE_VIDEO"
    case diaryNoteRecordAudio = "DIARYNOTE_CREATE_AUDIO"
    case diaryNoteCreateText = "DIARYNOTE_CREATE_TEXT"
    case diaryNoteFabNoticed = "DIARYNOTE_FAB_NOTICED"
    case diaryNoteFabReflection = "DIARYNOTE_FAB_REFLECTION"
    case diaryNoteCreateTextTitle = "DIARYNOTE_CREATE_TEXT_TITLE"
    case diaryNoteCreateTextSave = "DIARYNOTE_CREATE_TEXT_SAVE"
    case diaryNoteCreateTextConfirm = "DIARYNOTE_CREATE_TEXT_CONFIRM"
    case diaryNoteCreateTextEdit = "DIARYNOTE_CREATE_TEXT_EDIT"
    case diaryNoteCreateVideoSave = "DIARYNOTE_CREATE_VIDEO_SAVE"
    case diaryNoteCreateAudioTitle = "DIARYNOTE_CREATE_AUDIO_TITLE"
    case diaryNoteCreateAudioSave = "DIARYNOTE_CREATE_AUDIO_SAVE"
    case diaryNoteCreateVideoTitle = "DIARYNOTE_CREATE_VIDEO_TITLE"
    case diaryNoteEmptyViewTitle = "DIARYNOTE_EMPTY_VIEW_TITLE"
    case diaryNoteEmptyViewDescription = "DIARYNOTE_EMPTY_VIEW_DESCRIPTION"
    case diaryNoteTranscribeTextTitle = "DIARYNOTE_TRANSCRIBE_TEXT_TITLE"
    case diaryNoteTranscribeTextDescription = "DIARYNOTE_TRANSCRIBE_TEXT_DESCRIPTION"
    case diaryNoteTranscribeTextError = "DIARYNOTE_TRANSCRIBE_TEXT_ERROR"
    case diaryNotePlaceholder = "DIARY_NOTE_PLACEHOLDER"
    case diaryNoteDosesCell = "DIARY_NOTE_DOSES_CELL"
    case diaryNoteEatenCell = "DIARY_NOTE_EATEN_CELL"
    case diaryNoteNoticedCell = "DIARY_NOTE_NOTICED_CELL"
    case emojiList = "EMOJI_LIST"
    case emojiTitle = "EMOJI_TITLE"
    case emojiButtonText = "EMOJI_BUTTON"
    case diaryNoteTagDoses = "DIARY_NOTE_TAG_DOSES"
    case diaryNoteTagEaten = "DIARY_NOTE_TAG_EATEN"
    case diaryNoteTagNoticed = "DIARY_NOTE_TAG_NOTICED"
    case diaryNoteTagReflection = "DIARY_NOTE_TAG_REFLECTION"
    case diaryNoteTagWeNoticed = "DIARY_NOTE_TAG_WE_NOTICED"
    
    // I Have Eaten
    case diaryNoteFabEaten = "FAB_I_HAVE_EATEN"
    case diaryNoteEatenStepOneTitle = "EATEN_STEP_ONE_TITLE"
    case diaryNoteEatenStepOneMessage = "EATEN_STEP_ONE_MESSAGE"
    case diaryNoteEatenStepOneFirstButton = "EATEN_STEP_ONE_FIRST_BUTTON"
    case diaryNoteEatenStepOneSecondButton = "EATEN_STEP_ONE_SECOND_BUTTON"
    case diaryNoteEatenStepTwoTitle = "EATEN_STEP_TWO_TITLE"
    case diaryNoteEatenStepTwoMessage = "EATEN_STEP_TWO_MESSAGE"
    case diaryNoteEatenStepTwoFirstButton = "EATEN_STEP_TWO_FIRST_BUTTON"
    case diaryNoteEatenStepTwoSecondButton = "EATEN_STEP_TWO_SECOND_BUTTON"
    case diaryNoteEatenStepThreeTitle = "EATEN_STEP_THREE_TITLE"
    case diaryNoteEatenStepThreeMessage = "EATEN_STEP_THREE_MESSAGE"
    case diaryNoteEatenStepThreeTime = "EATEN_STEP_THREE_TIME"
    case diaryNoteEatenStepFourthTitle = "EATEN_STEP_FOURTH_TITLE"
    case diaryNoteEatenStepFourthMessage = "EATEN_STEP_FOURTH_MESSAGE"
    case diaryNoteEatenStepFourthFirstButton = "EATEN_STEP_FOURTH_FIRST_BUTTON"
    case diaryNoteEatenStepFourthSecondButton = "EATEN_STEP_FOURTH_SECOND_BUTTON"
    case diaryNoteEatenStepFourthThirdButton = "EATEN_STEP_FOURTH_THIRD_BUTTON"
    case diaryNoteEatenStepFifthTitle = "EATEN_STEP_FIFTH_TITLE"
    case diaryNoteEatenStepFifthMessage = "EATEN_STEP_FIFTH_MESSAGE"
    case diaryNoteEatenStepFifthFirstButton = "EATEN_STEP_FIFTH_FIRST_BUTTON"
    case diaryNoteEatenStepFifthSecondButton = "EATEN_STEP_FIFTH_SECOND_BUTTON"
    case diaryNoteEatenNextButton = "EATEN_NEXT_BUTTON"
    case diaryNoteEatenConfirmButton = "EATEN_CONFIRM_BUTTON"
    
    // My Doses
    case diaryNoteFabDoses = "FAB_MY_DOSES"
    case doseNextButton = "DOSE_NEXT_BUTTON"
    case doseStepOneTitle = "DOSE_STEP_ONE_TITLE"
    case doseStepOneMessage = "DOSE_STEP_ONE_MESSAGE"
    case doseStepOneFirstButton = "DOSE_STEP_ONE_FIRST_BUTTON"
    case doseStepOneSecondButton = "DOSE_STEP_ONE_SECOND_BUTTON"
    case doseStepTwoTimeLabel = "DOSE_STEP_TWO_TIME_LABEL"
    case doseStepTwoTitle = "DOSE_STEP_TWO_TITLE"
    case doseStepTwoMessage = "DOSE_STEP_TWO_MESSAGE"
    case doseStepTwoUnitsLabel = "DOSE_STEP_TWO_UNITS_LABEL"
    case doseStepTwoDosesLabel = "DOSE_STEP_TWO_DOSES_LABEL"
    case doseStepTwoConfirmButton = "DOSE_STEP_TWO_CONFIRM_BUTTON"
    
    // Video Diary
    case videoDiaryRecorderInfoFilter = "VIDEO_DIARY_RECORDER_INFO_FILTER"
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
    
    // Spyro Task
    case spiroTitle = "TASK_SPIRO_TITLE"
    case spiroSubtitle = "TASK_SPIRO_SUBTITLE"
    case spiroScan = "TASK_SPIRO_BUTTON_SCAN"
    case spiroStop = "TASK_SPIRO_BUTTON_STOP"
    case spiroNext = "TASK_SPIRO_BUTTON_NEXT"
    case spiroGetStarted = "TASK_SPIRO_BUTTON_GET_STARTED"
    case spiroNoBluetoothTitle = "TASK_SPIRO_NO_BLUETOOTH_TITLE"
    case spiroNoBluetoothDesc = "TASK_SPIRO_NO_BLUETOOTH_DESCRIPTION"
    case spiroNoDeviceTitle = "TASK_SPIRO_NO_DEVICE_TITLE"
    case spiroNoDeviceDesc = "TASK_SPIRO_NO_DEVICE_DESCRIPTION"
    case spiroIntroTestTitle = "TASK_SPIRO_INTRO_TEST_TITLE"
    case spiroIntroTestBody = "TASK_SPIRO_INTRO_TEST_BODY"
    case spiroSelectDevice = "TASK_SPIRO_SELECT_DEVICE"
    case spiroTaskCompleteTitle = "TASK_SPIRO_ACTIVITY_COMPLETE_TITLE"
    case spiroTaskCompleteBody = "TASK_SPIRO_ACTIVITY_COMPLETE_BODY"
    case spiroTaskButtonRedo = "TASK_SPIRO_ACTIVITY_BUTTON_REDO"
    case spiroTaskButtonDone = "TASK_SPIRO_ACTIVITY_BUTTON_DONE"
    case spiroTaskTargets = "TASK_SPIRO_ACTIVITY_TARGETS"
    case spiroTaskMeasurements = "TASK_SPIRO_ACTIVITY_MEASUREMENTS"
    case spiroTaskMeasCalloutTitle = "TASK_SPIRO_ACTIVITY_MEASUREMENTS_CALLOUT_TITLE"
    case spiroTaskMeasCalloutBody = "TASK_SPIRO_ACTIVITY_MEASUREMENTS_CALLOUT_BODY"
    case spiroTaskResults = "TASK_SPIRO_ACTIVITY_RESULTS"
    case spiroTaskResultsCalloutTitle = "TASK_SPIRO_ACTIVITY_RESULTS_CALLOUT_TITLE"
    case spiroTaskResultsCalloutBody = "TASK_SPIRO_ACTIVITY_RESULTS_CALLOUT_BODY"
    case spiroTaskPef = "TASK_SPIRO_ACTIVITY_PEF"
    case spiroTaskPefCalloutTitle = "TASK_SPIRO_ACTIVITY_PEF_CALLOUT_TITLE"
    case spiroTaskPefCalloutBody = "TASK_SPIRO_ACTIVITY_PEF_CALLOUT_BODY"
    case spiroTaskFev1 = "TASK_SPIRO_ACTIVITY_FEV1"
    case spiroTaskFev1CalloutTitle = "TASK_SPIRO_ACTIVITY_FEV1_CALLOUT_TITLE"
    case spiroTaskFev1CalloutBody = "TASK_SPIRO_ACTIVITY_FEV1_CALLOUT_BODY"
    case spiroTaskDeviceDisconnectedTitle = "TASK_SPIRO_DEVICE_DISCONNECTED_TITLE"
    case spiroTaskDeviceDisconnectedBody = "TASK_SPIRO_DEVICE_DISCONNECTED_BODY"
    case spiroTitleMedicalAlertTitle = "TASK_SPIRO_ALERT_DIALOG_TITLE"
    case spiroTitleMedicalAlertMessage = "TASK_SPIRO_ALERT_DIALOG_MESSAGE"
    case spiroTitleMedicalAlertButtonText = "TASK_SPIRO_ALERT_DIALOG_BUTTON"
    
    // Reflection Task
    case reflectionTextTask = "REFLECTION_CREATE_TEXT"
    case reflectionAudioTask = "REFLECTION_CREATE_AUDIO"
    case reflectionVideoTask = "REFLECTION_CREATE_VIDEO"
    case reflectionTaskTitle = "REFLECTION_TASK_TITLE"
    case reflectionTaskBody = "REFLECTION_TASK_BODY"
    case reflectionTaskLearnMore = "REFLECTION_TASK_LEARN_MORE"
    case reflectionLearnMoreClose = "REFLECTION_LEARN_MORE_CLOSE"
    
    // We have Noticed
    case noticedStepOneTitle = "NOTICED_STEP_ONE_TITLE"
    case noticedStepOneMessage = "NOTICED_STEP_ONE_MESSAGE"
    case noticedStepOneFirstButton = "NOTICED_STEP_ONE_FIRST_BUTTON"
    case noticedStepOneSecondButton = "NOTICED_STEP_ONE_SECOND_BUTTON"
    case noticedStepTwoTitle = "NOTICED_STEP_TWO_TITLE"
    case noticedStepTwoMessage = "NOTICED_STEP_TWO_MESSAGE"
    case noticedStepTwoFirstButton = "NOTICED_STEP_TWO_FIRST_BUTTON"
    case noticedStepTwoSecondButton = "NOTICED_STEP_TWO_SECOND_BUTTON"
    case noticedStepThreeTitle = "NOTICED_STEP_THREE_TITLE"
    case noticedStepThreeMessage = "NOTICED_STEP_THREE_MESSAGE"
    case noticedStepThreeTime = "NOTICED_STEP_THREE_TIME_LABEL"
    case noticedStepThreeDoses = "NOTICED_STEP_THREE_DOSES_LABEL"
    case noticedStepThreeUnit = "NOTICED_STEP_THREE_UNITS_LABEL"
    case noticedStepFourTitle = "NOTICED_STEP_FOUR_TITLE"
    case noticedStepFourMessage = "NOTICED_STEP_FOUR_MESSAGE"
    case noticedStepFourFirstButton = "NOTICED_STEP_FOUR_FIRST_BUTTON"
    case noticedStepFourSecondButton = "NOTICED_STEP_FOUR_SECOND_BUTTON"
    case noticedStepFiveTitle = "NOTICED_STEP_FIVE_TITLE"
    case noticedStepFiveMessage = "NOTICED_STEP_FIVE_MESSAGE"
    case noticedStepFiveFirstButton = "NOTICED_STEP_FIVE_FIRST_BUTTON"
    case noticedStepFiveSecondButton = "NOTICED_STEP_FIVE_SECOND_BUTTON"
    case noticedStepSixTitle = "NOTICED_STEP_SIX_TITLE"
    case noticedStepSixMessage = "NOTICED_STEP_SIX_MESSAGE"
    case noticedStepSixFirstButton = "NOTICED_STEP_SIX_FIRST_BUTTON"
    case noticedStepSixSecondButton = "NOTICED_STEP_SIX_SECOND_BUTTON"
    case noticedStepSevenTitle = "NOTICED_STEP_SEVEN_TITLE"
    case noticedStepSevenMessage = "NOTICED_STEP_SEVEN_MESSAGE"
    case noticedStepSevenTime = "NOTICED_STEP_SEVEN_TIME"
    case noticedStepEightTitle = "NOTICED_STEP_EIGHT_TITLE"
    case noticedStepEightMessage = "NOTICED_STEP_EIGHT_MESSAGE"
    case noticedStepEightFirstButton = "NOTICED_STEP_EIGHT_FIRST_BUTTON"
    case noticedStepEightSecondButton = "NOTICED_STEP_EIGHT_SECOND_BUTTON"
    case noticedStepEightThirdButton = "NOTICED_STEP_EIGHT_THIRD_BUTTON"
    case noticedStepNineTitle = "NOTICED_STEP_NINE_TITLE"
    case noticedStepNineMessage = "NOTICED_STEP_NINE_MESSAGE"
    case noticedStepNineFirstButton = "NOTICED_STEP_NINE_FIRST_BUTTON"
    case noticedStepNineSecondButton = "NOTICED_STEP_NINE_SECOND_BUTTON"
    case noticedStepTenTitle = "NOTICED_STEP_TEN_TITLE"
    case noticedStepTenMessage = "NOTICED_STEP_TEN_MESSAGE"
    case noticedStepTenFirstButton = "NOTICED_STEP_TEN_FIRST_BUTTON"
    case noticedStepTenSecondButton = "NOTICED_STEP_TEN_SECOND_BUTTON"
    case noticedStepTenThirdButton = "NOTICED_STEP_TEN_THIRD_BUTTON"
    case noticedStepTenFourthButton = "NOTICED_STEP_TEN_FOURTH_BUTTON"
    case noticedStepElevenTitle = "NOTICED_STEP_ELEVEN_TITLE"
    case noticedStepElevenMessage = "NOTICED_STEP_ELEVEN_MESSAGE"
    case noticedStepElevenFirstButton = "NOTICED_STEP_ELEVEN_FIRST_BUTTON"
    case noticedStepElevenSecondButton = "NOTICED_STEP_ELEVEN_SECOND_BUTTON"
    case noticedStepElevenThirdButton = "NOTICED_STEP_ELEVEN_THIRD_BUTTON"
    case noticedStepElevenFourthButton = "NOTICED_STEP_ELEVEN_FOURTH_BUTTON"
    case noticedStepElevenFifthButton = "NOTICED_STEP_ELEVEN_FIFTH_BUTTON"
    case noticedStepSuccessTitle = "NOTICED_STEP_SUCCESS_TITLE"
    case noticedStepSuccessMessage = "NOTICED_STEP_SUCCESS_MESSAGE"
    case noticedStepNextButton = "NOTICED_NEXT_BUTTON"
    case noticedStepConfirmButton = "NOTICED_CONFIRM_BUTTON"
    case weHaveNoticedMessage = "WE_HAVE_NOTICED_MESSAGE"

    // Study Info
    case studyInfoContactTitle = "STUDY_INFO_CONTACT_INFO"
    case studyInfoRewardsTitle = "STUDY_INFO_REWARDS"
    case studyInfoFaqTitle = "STUDY_INFO_FAQ"
    case studyInfoAboutYou = "STUDY_INFO_ABOUT_YOU"
    // About You
    case aboutYouUserInfo = "ABOUT_YOU_YOUR_PREGNANCY"
    case aboutYouAppsAndDevices = "ABOUT_YOU_APPS_AND_DEVICES"
    case aboutYouPreferences = "ABOUT_YOU_PREFERENCES"
    case aboutYouReviewConsent = "ABOUT_YOU_REVIEW_CONSENT"
    case aboutYouPermissions = "ABOUT_YOU_PERMISSIONS"
    case aboutYouDailySurveyTiming = "ABOUT_YOU_DAILY_SURVEY_TIMING_TITLE"
    case disclaimerFooter = "ABOUT_YOU_DISCLAIMER"
    case dailySurveyTimingHidden = "DAILY_SURVEY_TIMING_HIDDEN"
    case preferencesTitlePage = "PREFERENCES_TITLE_PAGE"
    case preferencesHour = "PREFERENCES_HOUR"
    case preferenceToggle = "PREFERENCES_TOGGLE"
    
    // User Info
    case userInfoButtonEdit = "PROFILE_USER_INFO_BUTTON_EDIT"
    case userInfoButtonSubmit = "PROFILE_USER_INFO_BUTTON_SUBMIT"
    case userInfoPermanentAlertTitle = "PROFILE_USER_INFO_PERMANENT_ALERT_TITLE"
    case userInfoPermanentAlertMessage = "PROFILE_USER_INFO_PERMANENT_ALERT_MESSAGE"
    case userInfoPermanentAlertConfirm = "PROFILE_USER_INFO_PERMANENT_ALERT_CONFIRM"
    case userInfoPermanentAlertCancel = "PROFILE_USER_INFO_PERMANENT_ALERT_CANCEL"
    // Permissions
    case permissionDeniedTitle = "PERMISSION_DENIED"
    case permissionSettings = "PERMISSION_SETTINGS"
    case permissionCancel = "PERMISSION_CANCEL"
    case permissionMessage = "PERMISSION_MESSAGE"
    case permissionHealthSettingsTitle = "PERMISSION_HEALTH_SETTINGS_TITLE"
    case permissionHealthSettingsMessage = "PERMISSION_HEALTH_SETTINGS_MESSAGE"
    case allowMessage = "PERMISSIONS_ALLOW"
    case allowedMessage = "PERMISSIONS_ALLOWED"
    case connectMessage = "YOUR_APPS_AND_DEVICES_CONNECT"
    case deauthorizeMessage = "YOUR_APPS_AND_DEVICES_DEAUTHORIZE"
    case permissionLocationDescription = "PERMISSION_LOCATION"
    case permissionPushNotificationDescription = "PERMISSION_PUSH_NOTIFICATION"
    case permissionHealthDescription = "PERMISSION_HEALTH"
    
    // DailySurvey Timing
    case dailySurveyTimingDescription = "ABOUT_YOU_DAILY_SURVEY_TIMING_DESCRIPTION"
    case dailySurveyTimingTitleButton = "ABOUT_YOU_DAILY_SURVEY_TIMING_TITLE_BUTTON"
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
    
    // OAuth
    case ouraOauthTitle = "OAUTH_OURA"
    case fitbitOauthTitle = "OAUTH_FITBIT"
    case garminOauthTitle = "OAUTH_GARMIN"
    case twitterOauthTitle = "OAUTH_TWITTER"
    case instagramOauthTitle = "OAUTH_INSTAGRAM"
    case rescueTimeOauthTitle = "OAUTH_RESCUETIME"
    case dexComOauthTitle = "OAUTH_DEXCOM"
    case terraTitle = "OAUTH_TERRA"
    case empaticaTitle = "OAUTH_EMPATICA"
    
    // Phase
    case phaseSwitchMessage = "PHASE_SWITCH_PROMPT"
    case phaseSwitchButtonConfirm = "PHASE_SWITCH_BUTTON_YES"
    case phaseSwitchButtonCancel = "PHASE_SWITCH_BUTTON_NO"
    case phaseNames = "STUDY_PHASES"
    
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
    
    private(set) static var fullStringMap: FullStringMap = [:]
    private static var requiredStringMap: RequiredStringMap = [:]
    
    static func initialize(withFullStringMap fullStringMap: FullStringMap, requiredStringMap: RequiredStringMap) {
        self.fullStringMap = fullStringMap
        self.requiredStringMap = requiredStringMap
    }
    
    static func string(forKey key: StringKey,
                       withParameters parameters: [String] = [],
                       forPhaseIndex phaseIndex: PhaseIndex? = nil) -> String {
        let string = {
            if let phaseIndex = phaseIndex, phaseIndex > 0 {
                let fullStringMapKey = "PHASE_\(phaseIndex + 1)_" + key.rawValue
                return self.fullStringMap[fullStringMapKey] ?? key.defaultValue
            } else {
                return self.requiredStringMap[key] ?? key.defaultValue
            }
        }()
        var formattedString = string
        for (index, element) in parameters.enumerated() {
            formattedString = formattedString.replacingOccurrences(of: "{\(index)}", with: element)
        }
        return formattedString
    }
    
    static func string(forText text: String,
                       withParameters parameters: [String] = []) -> String {
        
        var formattedString = text
        for (index, element) in parameters.enumerated() {
            formattedString = formattedString.replacingOccurrences(of: "{\(index)}", with: element)
        }
        return formattedString
    }
}

extension StringsProvider {
    /// Returns the array of MainTab configured in TAB_BAR_LIST,
    /// ensuring that 'feed' is always present.
    static func configuredMainTabs() -> [MainTab] {
        // Try to read the raw configuration string; default to empty if missing
        let raw = requiredStringMap[.tabBarList] ?? ""
        // Split by “;”, map to MainTab (filtering out invalid entries)
        var tabs = raw
            .split(separator: ";")
            .compactMap { MainTab(configKey: String($0)) }
        // Ensure 'feed' is always first
        if !tabs.contains(.feed) {
            tabs.insert(.feed, at: 0)
        }
        return tabs
    }
}
