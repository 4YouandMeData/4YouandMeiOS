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
    
    public static var orientationLock: UIInterfaceOrientationMask { OrientationManager.currentOrientationLock }
    
    public static func startup(withFontStyleMap fontStyleMap: FontStyleMap,
                               showDefaultUserInfo: Bool,
                               checkResourcesAvailability: Bool = false,
                               healthReadDataTypes: [HealthDataType] = []) -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        
        // Firebase Setup
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        
        // ProjectInfo Validation
        ProjectInfo.validate()
        
        // Prepare Specific app elements
        FontPalette.initialize(withFontStyleMap: fontStyleMap)
        
        #if DEBUG
        if checkResourcesAvailability {
            ImagePalette.checkImageAvailability()
            FontPalette.checkFontAvailability()
        }
        #endif
        
        // Prepare Logic
        let servicesSetupData = ServicesSetupData(showDefaultUserInfo: showDefaultUserInfo,
                                                  healthReadDataTypes: healthReadDataTypes)
        Services.shared.setup(withWindow: window, servicesSetupData: servicesSetupData)
        
        return window
    }
}
