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
    
    /// Boots the framework and returns a configured window for the host app.
    ///
    /// - Parameter mirrorPrintToJam: When `true`, every `print(...)` /
    ///   `debugPrint(...)` from the host app and the framework is captured
    ///   into Jam recordings (via stdout/stderr piping), while still
    ///   appearing in Xcode's debug console. **Note**: log lines may
    ///   contain user data, so a host app team must opt in knowingly —
    ///   anything they print during a Jam recording is included in the
    ///   recording. Default `false`.
    public static func startup(withFontStyleMap fontStyleMap: FontStyleMap,
                               showDefaultUserInfo: Bool,
                               appleWatchAlternativeIntegrations: [Integration],
                               checkResourcesAvailability: Bool = false,
                               enableLocationServices: Bool = true,
                               healthReadDataTypes: [HealthDataType] = [],
                               defaultDoseType: DoseType? = nil,
                               mirrorPrintToJam: Bool = false) -> UIWindow {
        if mirrorPrintToJam {
            StdoutMirror.install()
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()

        // Smoke-test emit-point for JamLog (FUAM-3074). Lands AFTER
        // makeKeyAndVisible so JamLog's `Logger.shared` registers its
        // sceneCaptureState observer against a valid keyWindow.
        let podVersion = PodUtils.getPodResourceBundle(withName: "ForYouAndMe")?
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        FYAMLog.info("ForYouAndMe v\(podVersion) started")

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
                                                  enableLocationServices: enableLocationServices,
                                                  healthReadDataTypes: healthReadDataTypes,
                                                  appleWatchAlternativeIntegrations: appleWatchAlternativeIntegrations,
                                                  defaultDoseType: defaultDoseType)
        Services.shared.setup(withWindow: window, servicesSetupData: servicesSetupData)
        
        return window
    }
}
