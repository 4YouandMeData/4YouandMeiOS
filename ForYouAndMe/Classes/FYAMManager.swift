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
    public static func startup(withAppId appId: String) -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        
        // Firebase Setup
        FirebaseApp.configure()
        
        // Prepare Logic
        Services.shared.setup(withWindow: window)
        
        return window
    }
}
