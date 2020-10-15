//
//  NotificationManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/10/2020.
//

import Foundation
import RxSwift
import FirebaseMessaging

protocol NotificationDeeplinkHandler: class {
    func receivedNotificationDeeplinkedTaskId(taskId: String)
    func receivedNotificationDeeplinkedURL(url: URL)
}

protocol NotificationTokenHandler: class {
    func registerNotificationToken(token: String)
}

class NotificationManager: NSObject, NotificationService {
    
    private enum DeeplinkKey: String, CaseIterable {
        case taskId = "task_id"
        case url
    }
    
    private let notificationDeeplinkHandler: NotificationDeeplinkHandler
    private let notificationTokenHandler: NotificationTokenHandler
    
    init(withNotificationDeeplinkHandler notificationDeeplinkHandler: NotificationDeeplinkHandler,
         notificationTokenHandler: NotificationTokenHandler) {
        self.notificationDeeplinkHandler = notificationDeeplinkHandler
        self.notificationTokenHandler = notificationTokenHandler
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }
    
    // MARK: - Private Methods
    
    private func processPushPayload(userInfo: [AnyHashable: Any]) {
        DeeplinkKey.allCases.forEach { deeplinkKey in
            if let value = userInfo[deeplinkKey.rawValue] {
                switch deeplinkKey {
                case .taskId:
                    guard let valueString = value as? String else {
                        return
                    }
                    self.notificationDeeplinkHandler.receivedNotificationDeeplinkedTaskId(taskId: valueString)
                case .url:
                    guard let valueString = value as? String, let deepLinkedUrl = URL(string: valueString) else {
                        return
                    }
                    self.notificationDeeplinkHandler.receivedNotificationDeeplinkedURL(url: deepLinkedUrl)
                }
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    // This method will be called when app received push notifications in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Not handled as soon as the push arrives in foreground. The alert is still shown and, if tapped, calls the callback below
        completionHandler([[.alert, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        self.processPushPayload(userInfo: userInfo)
        completionHandler()
    }
}

extension NotificationManager: MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        self.notificationTokenHandler.registerNotificationToken(token: fcmToken)
    }
    // [END refresh_token]
}
