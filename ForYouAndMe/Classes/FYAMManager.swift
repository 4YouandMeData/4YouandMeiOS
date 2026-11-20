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
    
    /// The window built by the first `startup` call. Later calls return it unchanged (FUAM-4519).
    /// Internal, not private: test seam (the test bundle links its own copy of the framework).
    static var startedWindow: UIWindow?
    
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
    ///
    /// Idempotent: the first call in a process does the one-time setup (Firebase, services) and later
    /// calls return the same window, ignoring their parameters. Main thread only.
    public static func startup(withFontStyleMap fontStyleMap: FontStyleMap,
                               showDefaultUserInfo: Bool,
                               appleWatchAlternativeIntegrations: [Integration],
                               checkResourcesAvailability: Bool = false,
                               enableLocationServices: Bool = true,
                               healthReadDataTypes: [HealthDataType] = [],
                               defaultDoseType: DoseType? = nil,
                               mirrorPrintToJam: Bool = false,
                               networkBodyCaptureMode: NetworkBodyCaptureMode = .truncated) -> UIWindow {
        assert(Thread.isMainThread, "FYAMManager.startup must be called on the main thread")
        if let startedWindow = startedWindow {
            #if DEBUG
            print("FYAMManager.startup already ran in this process: reusing the cached window, parameters ignored")
            #endif
            return startedWindow
        }

        // FUAM-4518: start-up timestamp for the X-Client-Process-Uptime-Ms header.
        ClientMetadataPlugin.markStartup()

        if mirrorPrintToJam {
            StdoutMirror.install()
        }

        // Stash the network capture mode for NetworkApiGateway to read
        // when it builds its plugin chain in `Services.shared.setup(...)`.
        TelemetryConfig.networkBodyCaptureMode = networkBodyCaptureMode

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()

        // Firebase Setup
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)

        // FUAM-4518: attribute start-up crashes to the stored participant. CacheManager reads UserDefaults only,
        // so it needs no Services graph.
        CrashlyticsSink.setUser(id: CacheManager().user?.id)

        // FUAM-4518: daily MetricKit app-exit report. Registered right after Firebase, before the services build
        // (idempotent: subscribes once per process).
        AppExitMetricsReporter.start()
        
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

        startedWindow = window
        
        return window
    }
}
