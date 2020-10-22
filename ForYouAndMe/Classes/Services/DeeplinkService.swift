//
//  DeeplinkService.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 12/10/2020.
//
import Foundation
import RxSwift

enum Deeplink {
    case openTask(taskId: String)
    case openUrl(url: URL)
    case openIntegrationApp(integration: Integration)
}

protocol DeeplinkService: class {
    var currentDeeplink: Deeplink? { get }
    func clearCurrentDeeplinkedData()
}
