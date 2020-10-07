//
//  AppDelegate.swift
//  ForYouAndMe
//
//  Created by LeonardoPasseri on 04/22/2020.
//  Copyright (c) 2020 LeonardoPasseri. All rights reserved.
//

import UIKit
import ForYouAndMe
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    let gcmMessageIDKey = "gcm.message_id"
    
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
        Messaging.messaging().delegate = self
        return true
    }
}

@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        
        // Change this to your preferred presentation option
        completionHandler([[.alert, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print full message.
        print(userInfo)
        
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        
        let dataDict: [String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    // [END refresh_token]
}
