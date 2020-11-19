//
//  OnboardingSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/11/2020.
//

import Foundation

enum OnboardingSection: String, Codable {
    case introVideo = "intro_video"
    case screeningSection = "screening"
    case informedConsentSection = "informed_consent"
    case consentSection = "consent"
    case optInSection = "opt_in"
    case consentUserDataSection = "consent_user_data"
    case integrationSection = "integration"
}
