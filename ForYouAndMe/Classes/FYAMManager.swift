//
//  FYAMManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import FirebaseCore

public class FYAMManager {
    
    public static func startup(withStudyId studyId: String,
                               fontStyleMap: FontStyleMap,
                               checkResourcesAvailability: Bool = false) -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        
        // Firebase Setup
        FirebaseApp.configure()
        
        // Prepare Specific app elements
        FontPalette.initialize(withFontStyleMap: fontStyleMap)
        
        #if DEBUG
        if checkResourcesAvailability {
            ImagePalette.checkImageAvailability()
            FontPalette.checkFontAvailability()
        }
        #endif
        
        // Prepare Logic
        Services.shared.setup(withWindow: window, studyId: studyId)
        
        return window
    }
}
