//
//  AnalyticsService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

enum AnalyticsEvent {
    // Screening
    case screeningQuizCompleted(answers: [Answer])
    // Informed Consent
    case informedConsentQuizCompleted(answers: [Answer])
    // TODO: Remove!!
    case testFirebaseEvent(sampleParameter: Int)
}

protocol AnalyticsService {
    func track(event: AnalyticsEvent)
}
