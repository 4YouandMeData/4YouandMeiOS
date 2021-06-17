//
//  NotificationManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/10/2020.
//

import Foundation
import RxSwift
import FirebaseMessaging

protocol NotificationTokenDelegate: AnyObject {
    func registerNotificationToken(token: String)
}

protocol NotificationDeeplinkHandler: AnyObject {
    func receivedNotificationDeeplinkedOpenTaskId(forTaskId taskId: String)
    func receivedNotificationDeeplinkedOpenURL(forUrl url: URL)
    func receivedNotificationDeeplinkedOpenIntegrationApp(forIntegrationName integrationName: String)
}

class NotificationManager: NSObject, NotificationService {
    
    private enum DeeplinkKey: String, CaseIterable {
        case taskId = "task_id"
        case url
        case openIntegrationApp = "open_app_integration"
    }
    
    weak var notificationTokenDelegate: NotificationTokenDelegate?
    
    private let notificationDeeplinkHandler: NotificationDeeplinkHandler
    
    init(withNotificationDeeplinkHandler notificationDeeplinkHandler: NotificationDeeplinkHandler) {
        self.notificationDeeplinkHandler = notificationDeeplinkHandler
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }
    
    // MARK: - NotificationService
    
    func getRegistrationToken() -> Single<String?> {
        return Single.create { singleEvent -> Disposable in
            Messaging.messaging().token { token, error in
              if nil != error {
                singleEvent(.error(NotificationError.fetchRegistrationTokenError))
              } else {
                singleEvent(.success(token))
              }
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Private Methods
    
    private func processPushPayload(userInfo: [AnyHashable: Any]) {
        guard let deeplinkKey = DeeplinkKey.allCases.first(where: { nil != userInfo[$0.rawValue] }),
              let value = userInfo[deeplinkKey.rawValue] else {
            return
        }
        switch deeplinkKey {
        case .taskId:
            guard let valueString = value as? String else {
                return
            }
            self.notificationDeeplinkHandler.receivedNotificationDeeplinkedOpenTaskId(forTaskId: valueString)
        case .url:
            guard let valueString = value as? String, let deepLinkedUrl = URL(string: valueString) else {
                return
            }
            self.notificationDeeplinkHandler.receivedNotificationDeeplinkedOpenURL(forUrl: deepLinkedUrl)
        case .openIntegrationApp:
            guard let valueString = value as? String else {
                return
            }
            self.notificationDeeplinkHandler.receivedNotificationDeeplinkedOpenIntegrationApp(forIntegrationName: valueString)
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
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("Firebase registration token missing")
            return
        }
        
        print("Firebase registration token: \(fcmToken)")
        guard let notificationTokenDelegate = notificationTokenDelegate else {
            assertionFailure("Missing expected notificationTokenDelegate")
            return
        }
        notificationTokenDelegate.registerNotificationToken(token: fcmToken)
    }
    // [END refresh_token]
}
