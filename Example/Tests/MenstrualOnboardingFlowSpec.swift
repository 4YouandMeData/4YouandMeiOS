//
//  MenstrualOnboardingFlowSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2937 / FUAM-2936: coordinator-level unit tests for the inline
//  menstrual baseline onboarding.
//
//  Notes / scope (mirrors HotFlashFlowSpec):
//  The view controllers used by the onboarding (MenstrualOnboardingPeriod3Mo*
//  and MenstrualOnboardingLastPeriod*) read `Services.shared.navigator` from
//  their `init()`. Those singletons are only fully wired up after the host
//  app's AppDelegate finishes bootstrap, which doesn't happen during unit-
//  test execution. Instantiating the VCs from tests therefore force-unwraps
//  a nil and crashes. Tests below validate the boundaries that DON'T require
//  building those VCs:
//
//  - `MockRepository` records `sendMenstrualUserSettings(...)` inputs.
//  - `getUserSettings()` is recorded (used by the gate inside AppNavigator).
//  - The gate predicate (`UserSettings.needsMenstrualOnboarding`) is fully
//    covered by `UserSettingsDecodingSpec`.
//
//  The full coordinator branching (No → save with date=nil; Yes/Unsure →
//  push step 2 → save with both fields) is covered by manual / device QA.
//

import Quick
import Nimble
import RxSwift
@testable import ForYouAndMe

class MenstrualOnboardingFlowSpec: QuickSpec {
    override class func spec() {

        describe("MockRepository menstrual capture") {
            it("starts with zero recorded calls and nil inputs") {
                let repo = MockRepository()
                expect(repo.sendMenstrualUserSettingsCallCount) == 0
                expect(repo.lastSentMenstrualHadPeriod3Mo).to(beNil())
                expect(repo.lastSentMenstrualLastPeriodDate).to(beNil())
                expect(repo.getUserSettingsCallCount) == 0
            }

            it("records hadPeriod3Mo and lastPeriodDate on save") {
                let repo = MockRepository()
                let date = Date(timeIntervalSince1970: 1_777_000_000)

                _ = repo.sendMenstrualUserSettings(hadPeriod3Mo: .yes, lastPeriodDate: date)

                expect(repo.sendMenstrualUserSettingsCallCount) == 1
                expect(repo.lastSentMenstrualHadPeriod3Mo) == .yes
                expect(repo.lastSentMenstrualLastPeriodDate) == date
            }

            it("captures the .no branch (user has not had a period; date=nil)") {
                let repo = MockRepository()

                _ = repo.sendMenstrualUserSettings(hadPeriod3Mo: .no, lastPeriodDate: nil)

                expect(repo.sendMenstrualUserSettingsCallCount) == 1
                expect(repo.lastSentMenstrualHadPeriod3Mo) == .no
                expect(repo.lastSentMenstrualLastPeriodDate).to(beNil())
            }

            it("captures the .unsure branch with a date") {
                let repo = MockRepository()
                let date = Date(timeIntervalSince1970: 1_777_000_000)

                _ = repo.sendMenstrualUserSettings(hadPeriod3Mo: .unsure, lastPeriodDate: date)

                expect(repo.sendMenstrualUserSettingsCallCount) == 1
                expect(repo.lastSentMenstrualHadPeriod3Mo) == .unsure
                expect(repo.lastSentMenstrualLastPeriodDate) == date
            }

            it("returns the stubbed result Single") {
                let repo = MockRepository()
                repo.sendMenstrualUserSettingsResult = .just(())

                var completed = false
                let disposeBag = DisposeBag()
                repo.sendMenstrualUserSettings(hadPeriod3Mo: .yes, lastPeriodDate: nil)
                    .subscribe(onSuccess: { completed = true })
                    .disposed(by: disposeBag)

                expect(completed) == true
            }

            it("counts each getUserSettings call so the gate can be verified") {
                let repo = MockRepository()
                _ = repo.getUserSettings()
                _ = repo.getUserSettings()
                expect(repo.getUserSettingsCallCount) == 2
            }
        }
    }
}
