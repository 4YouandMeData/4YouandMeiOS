//
//  AppDelegate.swift
//  ForYouAndMe
//
//  Created by LeonardoPasseri on 04/22/2020.
//  Copyright (c) 2020 LeonardoPasseri. All rights reserved.
//

import UIKit
import ForYouAndMe

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
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.header3] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: false)
        }
        if let font = UIFont(name: "Helvetica", size: 13.0) {
            fontStyleMap[.menu] = FontStyleData(font: font, lineSpacing: 3.0, uppercase: true)
        }
        self.window = FYAMManager.startup(withStudyId: "bump",
                                          fontStyleMap: fontStyleMap,
                                          showDefaultUserInfo: true,
                                          checkResourcesAvailability: true)
        return true
    }
}
