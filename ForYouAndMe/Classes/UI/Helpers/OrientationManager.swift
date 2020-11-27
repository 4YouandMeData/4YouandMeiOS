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
