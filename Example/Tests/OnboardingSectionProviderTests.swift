//
//  OnboardingSectionProviderTests.swift
//  ForYouAndMe_Tests
//
//  Created by Leonardo Passeri on 19/11/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Quick
import Nimble
@testable import ForYouAndMe

class OnboardingSectionProviderSpec: QuickSpec {
    override func spec() {
        context("OnboardingSectionProvider tests") {
            
            it("can handle empty list") {
                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: [])
                expect(OnboardingSectionProvider.firstOnboardingSection).to(beNil())
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .introVideo)).to(beNil())
            }
            
            it("can handle single group with single section") {
                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: [.introVideo])
                expect(OnboardingSectionProvider.firstOnboardingSection).to(equal(.introVideo))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .introVideo)).to(beNil())
            }

            it("can handle multiple group with single section") {
                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: [.integration, .screening, .introVideo])
                expect(OnboardingSectionProvider.firstOnboardingSection).to(equal(.integration))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .integration)).to(equal(.screening))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .screening)).to(equal(.introVideo))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .introVideo)).to(beNil())
            }

            it("can handle single group with multiple section") {
                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: [.consent])
                expect(OnboardingSectionProvider.firstOnboardingSection).to(equal(.informedConsent))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .informedConsent)).to(equal(.consent))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .consent)).to(equal(.optIn))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .optIn)).to(equal(.consentUserData))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .consentUserData)).to(beNil())
            }

            it("can handle default list") {
                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: [.introVideo, .screening, .consent, .integration])
                expect(OnboardingSectionProvider.firstOnboardingSection).to(equal(.introVideo))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .screening)).to(equal(.informedConsent))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .informedConsent)).to(equal(.consent))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .consent)).to(equal(.optIn))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .optIn)).to(equal(.consentUserData))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .consentUserData)).to(equal(.integration))
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .integration)).to(beNil())
            }

            it("can handle unexpected sections") {
                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: [.introVideo, .consent])
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .integration)).to(beNil())
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .screening)).to(beNil())

                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: [.screening, .integration])
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .introVideo)).to(beNil())
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .consentUserData)).to(beNil())
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .consent)).to(beNil())
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .informedConsent)).to(beNil())
                expect(OnboardingSectionProvider.getNextOnboardingSection(forOnboardingSection: .optIn)).to(beNil())
            }
        }
    }
}
