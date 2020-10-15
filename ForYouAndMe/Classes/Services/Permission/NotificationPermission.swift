//
//  NotificationPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import UserNotifications
import FirebaseMessaging

struct NotificationPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        guard let authorizationStatus = fetchAuthorizationStatus() else { return false }
        return authorizationStatus == .authorized
    }
    
    var isDenied: Bool {
        guard let authorizationStatus = fetchAuthorizationStatus() else { return false }
        return authorizationStatus == .denied
    }
    
    var isNotDetermined: Bool {
        guard let authorizationStatus = fetchAuthorizationStatus() else { return false }
        return authorizationStatus == .notDetermined
    }
    
    var isRestricted: Bool {
        return false
    }
    
    private func fetchAuthorizationStatus() -> UNAuthorizationStatus? {
        var notificationSettings: UNNotificationSettings?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global().async {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                notificationSettings = settings
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        return notificationSettings?.authorizationStatus
    }
    
    func request(completion: @escaping () -> Void?) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.badge, .alert, .sound]) { (_, _) in
            DispatchQueue.main.async {
                completion()
                Messaging.messaging().isAutoInitEnabled = true
            }
        }
        
        UIApplication.shared.registerForRemoteNotifications()
    }
}
