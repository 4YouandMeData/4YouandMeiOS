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
    
    init(api: ApiGateway) {
        self.platforms = [InternalAnalyticsPlatform(api: api), FirebaseAnalyticsPlatform()]
    }
    
    func track(event: AnalyticsEvent) {
        print("Analytics - Tracked event: \(event)")
        self.platforms.forEach({ $0.track(event: event) })
    }
}
