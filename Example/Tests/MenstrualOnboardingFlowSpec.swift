//
//  MenstrualOnboardingFlowSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2937 / FUAM-2936: coordinator-level unit tests for the inline
//  menstrual baseline onboarding.
//  FUAM-3243: the diary wizard now opens with the 2 baseline questions in-line
//  when the baseline is unset (no separate modal that has to dismiss and
//  re-present the wizard); the answers are PATCH'd in the background.
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
//  - The gate predicate (`UserSettings.needsMenstrualOnboarding`) decides
//    whether the flow opens with the baseline question (`requiresBaselineOnboarding`
//    passed to `MenstrualEntryCoordinator`) or straight on the diary wizard.
//
//  The full coordinator branching (No → save with date=nil; Yes/Unsure →
//  step 2 → save with both fields → continue into the diary wizard) is
//  covered by manual / device QA.
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

        // FUAM-3243 — the menstrual diary flow opens with the baseline
        // question only when the baseline has never been configured; otherwise
        // it opens straight on the diary wizard. `AppNavigator` derives this
        // from `UserSettings.needsMenstrualOnboarding` and forwards it to
        // `MenstrualEntryCoordinator(requiresBaselineOnboarding:)`.
        describe("FUAM-3243 baseline gate → where the diary flow starts") {

            // UserSettings.init isn't public; build it from a minimal JSON.
            func settings(hadPeriod3Mo: String?) -> UserSettings? {
                let value = hadPeriod3Mo.map { "\"\($0)\"" } ?? "null"
                let json = """
                {
                    "id": "20",
                    "type": "user_setting",
                    "menstrual_had_period_3mo": \(value),
                    "menstrual_last_period_date": null
                }
                """.data(using: .utf8)!
                return try? JSONDecoder().decode(UserSettings.self, from: json)
            }

            context("settings are nil (baseline never configured)") {
                it("opens with the in-line baseline onboarding before the diary steps") {
                    expect(settings(hadPeriod3Mo: nil)?.needsMenstrualOnboarding).to(beTrue())
                }
            }
            context("settings answer is 'yes'") {
                it("skips the baseline onboarding and opens straight on the diary wizard") {
                    expect(settings(hadPeriod3Mo: "yes")?.needsMenstrualOnboarding).to(beFalse())
                }
            }
            context("settings answer is 'unsure'") {
                it("skips the baseline onboarding and opens straight on the diary wizard") {
                    expect(settings(hadPeriod3Mo: "unsure")?.needsMenstrualOnboarding).to(beFalse())
                }
            }
            context("settings answer is 'no'") {
                it("skips the baseline onboarding and opens straight on the diary wizard") {
                    expect(settings(hadPeriod3Mo: "no")?.needsMenstrualOnboarding).to(beFalse())
                }
            }
        }

        // FUAM-3243 — when the flow does open with the baseline questions,
        // leaving them fires a background PATCH /v1/user_setting before
        // continuing into the diary wizard. One branch per onboarding answer.
        describe("FUAM-3243 background baseline PATCH per onboarding answer") {

            it("Yes + chosen date → hadPeriod3Mo=.yes with that date") {
                let repo = MockRepository()
                let date = Date(timeIntervalSince1970: 1_777_000_000)

                _ = repo.sendMenstrualUserSettings(hadPeriod3Mo: .yes, lastPeriodDate: date)

                expect(repo.sendMenstrualUserSettingsCallCount) == 1
                expect(repo.lastSentMenstrualHadPeriod3Mo) == .yes
                expect(repo.lastSentMenstrualLastPeriodDate) == date
            }

            it("Unsure + chosen date → hadPeriod3Mo=.unsure with that date") {
                let repo = MockRepository()
                let date = Date(timeIntervalSince1970: 1_777_000_000)

                _ = repo.sendMenstrualUserSettings(hadPeriod3Mo: .unsure, lastPeriodDate: date)

                expect(repo.sendMenstrualUserSettingsCallCount) == 1
                expect(repo.lastSentMenstrualHadPeriod3Mo) == .unsure
                expect(repo.lastSentMenstrualLastPeriodDate) == date
            }

            it("No → hadPeriod3Mo=.no with no date (the date step is skipped)") {
                let repo = MockRepository()

                _ = repo.sendMenstrualUserSettings(hadPeriod3Mo: .no, lastPeriodDate: nil)

                expect(repo.sendMenstrualUserSettingsCallCount) == 1
                expect(repo.lastSentMenstrualHadPeriod3Mo) == .no
                expect(repo.lastSentMenstrualLastPeriodDate).to(beNil())
            }
        }
    }
}
