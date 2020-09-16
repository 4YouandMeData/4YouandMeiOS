//
//  MotionPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import CoreMotion

struct MotionPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        if #available(iOS 11.0, *) {
            return CMMotionActivityManager.authorizationStatus() == .authorized
        }
        return false
    }
    
    var isDenied: Bool {
        if #available(iOS 11.0, *) {
            return CMMotionActivityManager.authorizationStatus() == .denied
        }
        return false
    }
    
    func request(completion: @escaping ()->()?) {
        let manager = CMMotionActivityManager()
        let today = Date()
        
        manager.queryActivityStarting(from: today, to: today, to: OperationQueue.main, withHandler: { (activities: [CMMotionActivity]?, error: Error?) -> () in
            completion()
            manager.stopActivityUpdates()
        })
    }
}
