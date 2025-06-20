//
//  AppDelegate.swift
//  ForYouAndMe
//
//  Created by LeonardoPasseri on 04/22/2020.
//  Copyright (c) 2020 LeonardoPasseri. All rights reserved.
//

import UIKit
import ForYouAndMe
import TerraiOS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        var fontStyleMap: FontStyleMap = [:]
        if let font = UIFont(name: "Helvetica", size: 24.0) {
            fontStyleMap[.title] = FontStyleData(font: font, lineSpacing: 6.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 20.0) {
            fontStyleMap[.header2] = FontStyleData(font: font, lineSpacing: 6.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 16.0) {
            fontStyleMap[.paragraph] = FontStyleData(font: font, lineSpacing: 5.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica-Bold", size: 16.0) {
            fontStyleMap[.paragraphBold] = FontStyleData(font: font, lineSpacing: 5.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.header3] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.menu] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: true)
        }
        if let font = UIFont(name: "Helvetica-Bold", size: 11.0) {
            fontStyleMap[.messages] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: true)
        }
        
        fontStyleMap[.infoNote] = FontStyleData(font: UIFont.boldSystemFont(ofSize: 11), lineSpacing: 3.0, uppercase: false)
        
        self.window = FYAMManager.startup(withFontStyleMap: fontStyleMap,
                                          showDefaultUserInfo: true,
                                          appleWatchAlternativeIntegrations: [.garmin, .fitbit],
                                          checkResourcesAvailability: true,
                                          enableLocationServices: true,
                                          healthReadDataTypes: HealthDataType.allCases)
        
        Terra.setUpBackgroundDelivery()
        
        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return FYAMManager.orientationLock
    }
}
