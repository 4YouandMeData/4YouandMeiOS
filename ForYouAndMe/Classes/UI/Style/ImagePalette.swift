//
//  ImagePalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

enum ImageName: String, CaseIterable {
    case setupFailure = "setupFailure"
    case failure = "failure"
    case fyamLogoSpecific = "fyam_logo_specific"
    case fyamLogoGeneric = "fyam_logo_generic"
    case mainLogo = "main_logo"
    case cziLogo = "czi_logo"
    case nextButtonPrimary = "next_button_primary"
    case backButtonPrimary = "back_button_primary"
    case nextButtonSecondary = "next_button_secondary"
    case nextButtonSecondaryDisabled = "next_button_secondary_disabled"
    case clearButton = "clear_button"
    case checkmark = "checkmark"
    case edit = "edit"
    case closeCircleButton = "close_circle_button"
    case videoCalendar = "video_calendar"
    case videoPause = "video_pause"
    case videoPlay = "video_play"
    case videoRecord = "video_record"
    case videoRecordResume = "video_resume_record"
    case videoRecordedFeedback = "video_recorded_feedback"
    case videoTime = "video_time"
    case cameraSwitch = "camera_switch"
    case flashOff = "flash_off"
    case flashOn = "flash_on"
    case filterIcon = "filter_icon"
    case filterOff = "filter_off"
    case filterOn = "filter_on"
    case circular = "circular"
    case clearCircular = "clear_circular"
    case fitbitIcon = "fitbit_icon"
    case rescueTimeIcon = "rescue_time_icon"
    case ouraIcon = "oura_icon"
    case garminIcon = "garmin_icon"
    case twitterIcon = "twitter_icon"
    case instagramIcon = "instagram_icon"
    case starFill = "star_fill"
    case starEmpty = "star_empty"
    case pushNotificationIcon = "push_notification_icon"
    case locationIcon = "location_icon"
    case healthIcon = "health_icon"
    case textNoteListImage = "text_note_list_image"
    case audioNoteListImage = "audio_note_list_image"
    case audioRecording = "audio_recording"
    case audioRecButton = "audio_recorder_button"
    case audioPauseButton = "audio_pause"
    case audioPlayButton = "audio_play"
    case noteGeneric = "note_generic_image"
    case riflectionIcon = "riflection_image"
    case audioNote = "audio_note"
    case textNote = "text_note"
    case editAudioNote = "edit_audio_note"
    case warningIcon = "warning_icon"
    case bluetoothIcon = "bluetooth_icon"
    case deviceConnected = "device_connected"
    case bluetoothNoDevices = "bluetooth_no_devices"
    case spiroIntroTestImage = "spiro_intro_image"
    case reflectionBrainIcon = "brain_logo"
    case reflectionEyeIcon = "eye_logo"
    case surveyIcon = "survey_icon"
    case terraIcon = "terra_icon"
    case pinchZoom = "pinch_zoom"
    case emojiICon = "emoji_icon"
}

enum TemplateImageName: String, CaseIterable {
    case audioPlayPreview = "audio_play_preview"
    case backButtonNavigation = "back_button_navigation"
    case checkboxOutline = "checkbox_outline"
    case checkboxFilled = "checkbox_filled"
    case radioButtonFilled = "radio_button_filled"
    case radioButtonOutline = "radio_button_outline"
    case tabFeed = "tab_feed"
    case tabTask = "tab_task"
    case tabDiary = "tab_diary"
    case tabUserData = "tab_user_data"
    case tabStudyInfo = "tab_study_info"
    case studyInfoContact = "contact_icon"
    case studyInfoRewards = "rewards_icon"
    case studyInfoFAQ = "faq_icon"
    case arrowRight = "arrow_right"
    case closeButton = "close_button"
    case userInfoIcon = "user_info_icon"
    case devicesIcon = "devices_icon"
    case preferenceIcon = "preference_icon"
    case reviewConsentIcon = "review_consent_icon"
    case permissionIcon = "permission_icon"
    case timingIcon = "survey_timing_icon"
    case editSmall = "edit_small"
    case filterIcon = "filter_icon"
    case videoIcon = "video_icon"
    case infoMessage = "info_message"
    case snackImage = "snack_image"
    case mealImage = "meal_image"
    case clockIcon = "clock_icon"
    case plusIcon = "plus_icon"
    case equalsIcon = "equals_icon"
    case minusIcon = "minus_icon"
    case eatenIcon = "eaten_image"
    case siringeIcon = "siringe_icon"
    case resetDots = "reset_icon"
    case medicalAlert = "medical_alert"
    case activityIconMild = "activity_icon_mild"
    case activityIconNo = "activity_icon_no"
    case activityIconModerate = "activity_icon_moderate"
    case activityIconVigorous = "activity_icon_vigorous"
    case stressIconLittle = "stress_icon_a_little"
    case stressIconNone = "stress_icon_none"
    case stressIconSome = "stress_icon_some"
    case stressIconStressed = "stress_icon_stressed"
    case stressIconVeryStressed = "stress_icon_very_stressed"
    case questionIcon = "question_icon"
    case weNoticedIcon = "we_noticed_icon"
}

public class ImagePalette {
    
    static func image(withName name: ImageName, forPhaseIndex phaseIndex: PhaseIndex? = nil) -> UIImage? {
        return Self.image(withName: name.rawValue, forPhaseIndex: phaseIndex)
    }
    
    static func templateImage(withName name: TemplateImageName, forPhaseIndex phaseIndex: PhaseIndex? = nil) -> UIImage? {
        return Self.image(withName: name.rawValue, forPhaseIndex: phaseIndex)?.withRenderingMode(.alwaysTemplate)
    }
    
    private static func image(withName name: String, forPhaseIndex phaseIndex: PhaseIndex? = nil) -> UIImage? {
        var completeName = name
        if let phaseIndex = phaseIndex {
            completeName += "_phase_\(phaseIndex)"
        }
        if let image = UIImage(named: completeName) {
            return image
        } else if let podBundle = PodUtils.getPodResourceBundle(withName: Constants.Resources.DefaultBundleName) {
            return UIImage(named: completeName, in: podBundle, with: nil)
        } else {
            return nil
        }
    }
    
    static func checkImageAvailability() {
        ImageName.allCases.forEach { imageName in
            assert(ImagePalette.image(withName: imageName) != nil, "missing image: \(imageName.rawValue)")
        }
        TemplateImageName.allCases.forEach { imageName in
            assert(ImagePalette.templateImage(withName: imageName) != nil, "missing template image: \(imageName.rawValue)")
        }
    }
}
