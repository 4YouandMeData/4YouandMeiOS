//
//  InternalAnalyticsPlatform.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

protocol InternalAnalyticsPlatformGateway {
    func sendScreeningAnswers(answers: [Answer])
}

class InternalAnalyticsPlatform: AnalyticsPlatform {
    
    private let gateway: InternalAnalyticsPlatformGateway
    
    init(gateway: InternalAnalyticsPlatformGateway) {
        self.gateway = gateway
    }
    
    func track(event: AnalyticsEvent) {
        switch event {
        case .screeningQuizCompleted(let answers):
            self.gateway.sendScreeningAnswers(answers: answers)
        }
    }
}
