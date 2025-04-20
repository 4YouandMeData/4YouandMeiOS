//
//  OrientationManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 20/11/2020.
//

import UIKit

struct OrientationManager {

    static var currentOrientationLock = defaultOrientationLock
    
    private static var defaultOrientationLock = UIInterfaceOrientationMask.portrait
    private static var defaultOrientation = UIInterfaceOrientation.portrait
    
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {

        self.currentOrientationLock = orientation
    }

    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation: UIInterfaceOrientation) {
   
        self.lockOrientation(orientation)
    
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }

    static func resetOrientationToDefault() {
   
        self.currentOrientationLock = self.defaultOrientationLock
        
        self.lockOrientation(self.defaultOrientationLock, andRotateTo: self.defaultOrientation)
    }
}

extension OrientationManager {
    /// Reset orientation to default, then invoke completion when rotation animation ends.
    static func resetToDefaultWithCompletion(_ completion: @escaping () -> Void) {
        // Lock back to default
        currentOrientationLock = defaultOrientationLock
        let delay = 0.35
        UIDevice.current.setValue(defaultOrientation.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()

        // 3. Schedule the completion after a small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion()
        }
    }
}
