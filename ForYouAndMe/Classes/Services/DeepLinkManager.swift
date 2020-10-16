//
//  DeepLinkManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/10/2020.
//

import Foundation
import RxSwift

private struct DeeplinkedTaskData {
    let taskId: String
    let expirationDate: Date
}

private struct DeeplinkedUrlData {
    let url: URL
    let expirationDate: Date
}

class DeeplinkManager: NSObject, DeeplinkService {
    
    // Deeplink expiry date
    private static let ExpirationTime: TimeInterval = 24*60*60
    
    public weak var navigator: AppNavigator!
    
    private var deeplinkedTaskData: DeeplinkedTaskData?
    private var deeplinkedUrlData: DeeplinkedUrlData?
    
    // MARK: - DeeplinkService
    
    func getDeeplinkedTaskId() -> String? {
        if let deeplinkedTaskData = self.deeplinkedTaskData, deeplinkedTaskData.expirationDate > Date() {
            return deeplinkedTaskData.taskId
        } else {
            return nil
        }
    }
    
    func clearDeeplinkedTaskData() {
        self.deeplinkedTaskData = nil
    }
    
    func getDeeplinkedUrl() -> URL? {
        if let deeplinkedUrlData = self.deeplinkedUrlData, deeplinkedUrlData.expirationDate > Date() {
            return deeplinkedUrlData.url
        } else {
            return nil
        }
    }
    
    func clearDeeplinkedUrlData() {
        self.deeplinkedUrlData = nil
    }
    
    // MARK: - Private Methods
    
    private func handleReceivedDeeplinkedTaskId(taskId: String) {
        print("DeeplinkManager - handleReceivedDeeplinkedTask for task id: '\(taskId)'")
        self.deeplinkedTaskData = DeeplinkedTaskData(taskId: taskId,
                                                     expirationDate: Date(timeIntervalSinceNow: (type(of: self)).ExpirationTime))
        self.navigator.handleDeeplinkToTask()
    }
    
    private func handleReceivedDeeplinkedURL(url: URL) {
        print("DeeplinkManager - handleReceivedDeeplinkedURL for url: '\(url)'")
        self.deeplinkedUrlData = DeeplinkedUrlData(url: url,
                                                   expirationDate: Date(timeIntervalSinceNow: (type(of: self)).ExpirationTime))
        self.navigator.handleDeeplinkToUrl()
    }
}

extension DeeplinkManager: NotificationDeeplinkHandler {
    
    func receivedNotificationDeeplinkedTaskId(taskId: String) {
        self.handleReceivedDeeplinkedTaskId(taskId: taskId)
    }
    
    func receivedNotificationDeeplinkedURL(url: URL) {
        self.handleReceivedDeeplinkedURL(url: url)
    }
}
