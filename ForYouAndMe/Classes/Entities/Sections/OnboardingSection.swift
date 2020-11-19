//
//  OnboardingSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/11/2020.
//

import Foundation

enum OnboardingSectionGroup: String, Codable {
    case introVideo = "intro_video"
    case screening = "screening"
    case consent = "consent_group"
    case integration = "integration"
    
    var sections: [OnboardingSection] {
        switch self {
        case .introVideo: return [.introVideo]
        case .screening: return [.screening]
        case .consent: return [.informedConsent, .consent, .optIn, .consentUserData]
        case .integration: return [.integration]
        }
    }
}

enum OnboardingSection {
    case introVideo
    case screening
    case informedConsent
    case consent
    case optIn
    case consentUserData
    case integration
}
