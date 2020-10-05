//
//  Constants.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import AVFoundation

enum TestSection {
    case introVideo
    case screeningSection
    case informedConsentSection
    case consentSection
    case optInSection
    case consentUserDataSection
    case wearablesSection
}

struct Constants {
    struct Test {
        static let NetworkStubsEnabled = false
        static let NetworkStubsDelay = 0.3
        static let NetworkLogVerbose = true
        
        static let Section: TestSection? = nil //.screeningSection
        static let OnboardingCompleted: Bool? = nil
        
        static let InformedConsentWithoutQuestions: Bool = false
        static let CheckGlobalStrings: Bool = false
        static let CheckGlobalColors: Bool = false
        static let LoremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce a convallis metus, et semper ex. Integer eros est, porttitor eget pulvinar at, molestie at tellus. Phasellus et velit dapibus, molestie erat a, gravida ligula. Proin pharetra ante nec ante egestas, sed dignissim leo sodales. Etiam rutrum nibh enim, non feugiat magna efficitur id. Praesent varius eleifend ante pretium vestibulum. Sed arcu ex, interdum in neque in, bibendum maximus justo. Duis vel efficitur metus. \nPellentesque at elit turpis. Mauris augue odio, dictum convallis turpis eget, viverra vulputate augue. Suspendisse sit amet ex mauris. Nam eget nisi eu urna congue commodo sit amet semper ex. Quisque fermentum libero vel nunc maximus ultrices. Vestibulum blandit eget erat in finibus. Quisque rutrum libero nulla, non dignissim quam eleifend in. Ut pellentesque lectus et leo viverra semper. Vestibulum diam nunc, blandit sit amet lorem a, scelerisque eleifend odio. In euismod nunc tincidunt lectus imperdiet dapibus."

    }
    struct Network {
        static let ApiBaseUrlStr = "https://api-4youandme-staging.balzo.eu/api"
        static let ApiOAuthWearables = "https://admin-4youandme-staging.balzo.eu/users/integration_oauth/"
    }
    
    struct Style {
        static let DefaultHorizontalMargins: CGFloat = 24.0
        static let DefaultFooterHeight: CGFloat = 134.0
        static let DefaultTextButtonHeight: CGFloat = 52.0
        static let FeedCellButtonHeight: CGFloat = 44.0
        static let EditButtonHeight: CGFloat = 26.0
    }
    struct Resources {
        static let DefaultBundleName: String = "ForYouAndMe"
        static let IntroVideoUrl: URL? = {
            guard let videoPathString = Bundle.main.path(forResource: "StudyVideo", ofType: "mp4") else {
                assertionFailure("Missing Study Video File")
                return nil
            }
            return URL(fileURLWithPath: videoPathString)
        }()
    }
    struct Misc {
        static let EnableGlobalConfigCache = false
        static let PhoneValidationCodeDigitCount: Int = 6
        static let EmailValidationCodeDigitCount: Int = 6
        static let VideoDiaryMaxDurationSeconds: TimeInterval = 120.0
        static let VideoDiaryCaptureSessionPreset: AVCaptureSession.Preset = .hd1280x720
    }
    
    struct Url {
        static let OuraStoreUrl: URL = URL(string: "itms-apps://apps.apple.com/it/app/oura/id1043837948")!
        static let OuraAppSchema: URL = URL(string: "oura://")!
        static let FitbitStoreUrl: URL = URL(string: "itms-apps://apps.apple.com/us/app/fitbit-health-fitness/id462638897")!
        static let FitbitAppSchema: URL = URL(string: "fitbit://")!
    }
    
    struct Task {
        static let fileResultMimeType = "application/json"
        
        static let taskResultURL: URL = {
            let documentsDirectoryString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            var resultDirectory = URL(fileURLWithPath: documentsDirectoryString, isDirectory: true)
            resultDirectory.appendPathComponent(FilePath.taskResult.rawValue)
            return resultDirectory
        }()
        
        static let videoResultURL: URL = {
            let documentsDirectoryString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            var resultDirectory = URL(fileURLWithPath: documentsDirectoryString, isDirectory: true)
            resultDirectory.appendPathComponent(FilePath.videoResult.rawValue)
            return resultDirectory
        }()
    }
    
    struct Survey {
        static let TargetQuit: String = "exit"
        static let NumericTypeMinValue: String = "min_display"
        static let NumericTypeMaxValue: String = "max_display"
    }
}

enum FilePath: String {
    case taskResult = "TaskResult"
    case videoResult = "VideoResult"
}
