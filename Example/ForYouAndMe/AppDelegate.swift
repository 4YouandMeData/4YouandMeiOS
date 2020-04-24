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
        
        self.window = FYAMManager.startup(withAppId: "TestAppId")
        
        return true
    }
}
