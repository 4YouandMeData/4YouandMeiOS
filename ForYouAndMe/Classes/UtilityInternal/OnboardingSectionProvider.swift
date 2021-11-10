//
//  OnboardingSectionProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/11/2020.
//

import Foundation

class OnboardingSectionProvider {
    
    static var onboardingSectionDriver: OnboardingSectionDriver?
    
    static var userConsentSectionExists: Bool { onboardingSectionDriver?.userConsentSectionExists ?? false }
    
    static func initialize(withOnboardingSectionGroups onboardingSectionGroups: [OnboardingSectionGroup]) {
        self.onboardingSectionDriver = OnboardingSectionDriver(onboardingSectionGroups: onboardingSectionGroups)
    }
}

struct OnboardingSectionDriver {
    
    var userConsentSectionExists: Bool { self.onboardingSectionGroups.contains(.consent) }
    
    var firstOnboardingSection: OnboardingSection? {
        return self.getFirstSectionFromFirstNonEmptyGroup(forStartingGroupIndex: 0)
    }
    
    private let onboardingSectionGroups: [OnboardingSectionGroup]
    
    init(onboardingSectionGroups: [OnboardingSectionGroup]) {
        self.onboardingSectionGroups = onboardingSectionGroups
    }
    
    func getNextOnboardingSection(forOnboardingSection onboardingSection: OnboardingSection) -> OnboardingSection? {
        guard let currentGroupIndex = self.onboardingSectionGroups.firstIndex(where: { $0.sections.contains(onboardingSection) }) else {
            // No group containing the given section has been found
            return nil
        }
        let currentGroup = self.onboardingSectionGroups[currentGroupIndex]
        if let currentSectionIndexInGroup = currentGroup.sections.firstIndex(of: onboardingSection),
           currentSectionIndexInGroup < currentGroup.sections.count - 1 {
            // Return the next section of the group, if it exists
            return currentGroup.sections[currentSectionIndexInGroup + 1]
        } else {
            return self.getFirstSectionFromFirstNonEmptyGroup(forStartingGroupIndex: currentGroupIndex + 1)
        }
    }
    
    private func getFirstSectionFromFirstNonEmptyGroup(forStartingGroupIndex startingGroupIndex: Int) -> OnboardingSection? {
        var section: OnboardingSection?
        var currentGroupIndex = startingGroupIndex
        while section == nil, currentGroupIndex < self.onboardingSectionGroups.count {
            section = self.onboardingSectionGroups[currentGroupIndex].sections.first
            currentGroupIndex += 1
        }
        return section
    }
}
