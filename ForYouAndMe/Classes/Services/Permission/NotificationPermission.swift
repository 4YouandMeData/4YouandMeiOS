//
//  NotificationPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import UserNotifications

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
        guard let authorizationStatus = fetchAuthorizationStatus() else { return false }
        return false
    }
    
    private func fetchAuthorizationStatus() -> UNAuthorizationStatus? {
        var notificationSettings: UNNotificationSettings?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global().async {
            UNUserNotificationCenter.current().getNotificationSettings { setttings in
                notificationSettings = setttings
                semaphore.signal()
            }
        }
        
        semaphore.wait()
        return notificationSettings?.authorizationStatus
    }
    
    func request(completion: @escaping () -> Void?) {
        if #available(iOS 10.0, tvOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.badge, .alert, .sound]) { (granted, error) in
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            #if os(iOS)
            UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.badge, .sound, .alert],
                                                                                             categories: nil))
            #endif
            DispatchQueue.main.async {
                completion()
            }
        }
        
        UIApplication.shared.registerForRemoteNotifications()
    }
}
