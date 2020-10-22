//
//  DeeplinkManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/10/2020.
//

import Foundation
import RxSwift

protocol DeeplinkManagerDelegate: class {
    func handleDeeplink(_ deeplink: Deeplink) -> Bool
}

class DeeplinkManager: NSObject, DeeplinkService {
    
    public weak var delegate: DeeplinkManagerDelegate?
    
    // MARK: - DeeplinkService
    
    var currentDeeplink: Deeplink?
    
    func clearCurrentDeeplinkedData() {
        print("DeeplinkManager - cleared current deeplink data")
        self.currentDeeplink = nil
    }
    
    // MARK: - Private Methods
    
    private func handleReceivedDeeplinkedOpenTaskId(forTaskId taskId: String) {
        print("DeeplinkManager - handleReceivedDeeplinkedOpenTaskId for task id: '\(taskId)'")
        self.sharedDeeplinkHandling(deepLink: Deeplink.openTask(taskId: taskId))
    }
    
    private func handleReceivedDeeplinkedOpenURL(forUrl url: URL) {
        print("DeeplinkManager - handleReceivedDeeplinkedOpenURL for url: '\(url)'")
        self.sharedDeeplinkHandling(deepLink: Deeplink.openUrl(url: url))
    }
    
    private func handleReceivedDeeplinkedOpenIntegrationApp(forIntegration integration: Integration) {
        print("DeeplinkManager - handleReceivedDeeplinkedOpenIntegrationApp for integration: '\(integration)'")
        self.sharedDeeplinkHandling(deepLink: Deeplink.openIntegrationApp(integration: integration))
    }
    
    private func sharedDeeplinkHandling(deepLink: Deeplink) {
        guard let delegate = self.delegate else {
            assertionFailure("Missing delegate")
            return
        }
        self.currentDeeplink = deepLink
        let deeplinkHasBeenHandled = delegate.handleDeeplink(deepLink)
        if deeplinkHasBeenHandled {
            self.clearCurrentDeeplinkedData()
        }
    }
}

extension DeeplinkManager: NotificationDeeplinkHandler {
    
    func receivedNotificationDeeplinkedOpenTaskId(forTaskId taskId: String) {
        self.handleReceivedDeeplinkedOpenTaskId(forTaskId: taskId)
    }
    
    func receivedNotificationDeeplinkedOpenURL(forUrl url: URL) {
        self.handleReceivedDeeplinkedOpenURL(forUrl: url)
    }
    
    func receivedNotificationDeeplinkedOpenIntegrationApp(forIntegration integration: Integration) {
        self.handleReceivedDeeplinkedOpenIntegrationApp(forIntegration: integration)
    }
}
