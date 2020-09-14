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
    case nextButtonPrimary = "next_button_primary"
    case backButtonPrimary = "back_button_primary"
    case nextButtonSecondary = "next_button_secondary"
    case nextButtonSecondaryDisabled = "next_button_secondary_disabled"
    case closeButton = "close_button"
    case clearButton = "clear_button"
    case checkmark = "checkmark"
    case edit = "edit"
    case closeCircleButton = "close_circle_button"
    case videoDiaryIntro = "video_diary_intro"
    case videoCalendar = "video_calendar"
    case videoPause = "video_pause"
    case videoPlay = "video_play"
    case videoRecord = "video_record"
    case videoRecordResume = "video_resume_record"
    case videoRecordedFeedback = "video_recorded_feedback"
    case videoTime = "video_time"
    case videoDiarySuccess = "video_diary_success"
    case cameraSwitch = "camera_switch"
    case flashOff = "flash_off"
    case flashOn = "flash_on"
    case circular = "circular"
    case clearCircular = "clear_circular"
    case fitbitIcon = "fitbit_icon"
    case ouraIcon = "oura_icon"
}

enum TemplateImageName: String, CaseIterable {
    case backButtonNavigation = "back_button_navigation"
    case checkboxOutline = "checkbox_outline"
    case checkboxFilled = "checkbox_filled"
    case radioButtonFilled = "radio_button_filled"
    case radioButtonOutline = "radio_button_outline"
    case notification = "notification"
    case tabFeed = "tab_feed"
    case tabTask = "tab_task"
    case tabUserData = "tab_user_data"
    case tabStudyInfo = "tab_study_info"
    case studyInfoContact = "contact_icon"
    case studyInfoRewards = "rewards_icon"
    case studyInfoFAQ = "faq_icon"
    case arrowRight = "arrow_right"
    case closeButtonTemplate = "close_button_template"
    case pregnancyIcon = "pregnancy_icon"
    case devicesIcon = "devices_icon"
    case reviewConsentIcon = "review_consent_icon"
    case permissionIcon = "permission_icon"
}

public class ImagePalette {
    
    static func image(withName name: ImageName) -> UIImage? {
        return Self.image(withName: name.rawValue)
    }
    
    static func templateImage(withName name: TemplateImageName) -> UIImage? {
        return Self.image(withName: name.rawValue)?.withRenderingMode(.alwaysTemplate)
    }
    
    private static func image(withName name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        } else if let podBundle = PodUtils.getPodResourceBundle(withName: Constants.Resources.DefaultBundleName) {
            return UIImage(named: name, in: podBundle, with: nil)
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
