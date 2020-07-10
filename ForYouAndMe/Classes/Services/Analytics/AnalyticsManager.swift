//
//  AnalyticsManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

protocol AnalyticsPlatform {
    func track(event: AnalyticsEvent)
}

class AnalyticsManager: AnalyticsService {
    
    private let platforms: [AnalyticsPlatform]
    
    init(gateway: InternalAnalyticsPlatformGateway) {
        self.platforms = [InternalAnalyticsPlatform(gateway: gateway)]
    }
    
    func track(event: AnalyticsEvent) {
        self.platforms.forEach({ $0.track(event: event) })
    }
}
