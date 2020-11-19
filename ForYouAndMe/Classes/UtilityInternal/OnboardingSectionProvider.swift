//
//  OnboardingSectionProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/11/2020.
//

import Foundation

class OnboardingSectionProvider {
    
    private static var onboardingSections: [OnboardingSection] = []
    
    static var firstOnboardingSection: OnboardingSection? {
        return self.onboardingSections.first
    }
    
    static func initialize(withOnboardingSections onboardingSections: [OnboardingSection]) {
        self.onboardingSections = onboardingSections
    }
    
    static func nextOnboardingSection(forOnboardingSection onboardingSection: OnboardingSection) -> OnboardingSection? {
        guard let currentOnboardingSectionIndex = self.onboardingSections.firstIndex(of: onboardingSection) else {
            return nil
        }
        let nextOnboardingSectionIndex = currentOnboardingSectionIndex + 1
        guard nextOnboardingSectionIndex < self.onboardingSections.count else {
            return nil
        }
        return self.onboardingSections[nextOnboardingSectionIndex]
    }
}
