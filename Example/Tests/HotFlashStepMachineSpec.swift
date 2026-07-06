//
//  HotFlashStepMachineSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3511: regression cover for the Hot Flash diary step machine.
//  A Back→Next round-trip used to write an answer into the wrong response
//  key (severity landing in duration, duration in symptoms, …) which the BE
//  rejected with a 422 and dropped the entry. Routing is now bound to the
//  confirming step's identity (`HotFlashStep`) and answers are written by the
//  key that step owns (`HotFlashAnswers.record(step:selected:)`), both pure
//  and UI-free, so this spec drives them directly without building any VC.
//

import Quick
import Nimble
@testable import ForYouAndMe

class HotFlashStepMachineSpec: QuickSpec {
    override class func spec() {

        describe("HotFlashStep navigation") {
            it("advances Severity → Duration → Symptoms → SleepOnset and stops") {
                expect(HotFlashStep.severity.next).to(equal(.duration))
                expect(HotFlashStep.duration.next).to(equal(.symptoms))
                expect(HotFlashStep.symptoms.next).to(equal(.sleepOnset))
                // Terminal step: no next screen, so submit fires instead of a push.
                expect(HotFlashStep.sleepOnset.next).to(beNil())
            }

            it("has exactly the four expected steps in push order") {
                expect(HotFlashStep.allCases).to(equal([.severity, .duration, .symptoms, .sleepOnset]))
            }
        }

        describe("HotFlashAnswers.record") {
            it("assembles all four keys under their own names on a correct forward pass") {
                var answers = HotFlashAnswers()
                answers.record(step: .severity, selected: ["warm", "hot"])
                answers.record(step: .duration, selected: ["one_to_two_minutes"])
                answers.record(step: .symptoms, selected: ["anxiety", "panic"])
                answers.record(step: .sleepOnset, selected: ["awake_with_sensation"])

                expect(answers.severity).to(equal(["warm", "hot"]))
                expect(answers.duration).to(equal("one_to_two_minutes"))
                expect(answers.symptoms).to(equal(["anxiety", "panic"]))
                expect(answers.sleepOnset).to(equal("awake_with_sensation"))
            }

            it("keeps single-select steps to their first code") {
                var answers = HotFlashAnswers()
                answers.record(step: .duration, selected: ["one_to_two_minutes", "junk"])
                answers.record(step: .sleepOnset, selected: ["awake_with_sensation", "junk"])
                expect(answers.duration).to(equal("one_to_two_minutes"))
                expect(answers.sleepOnset).to(equal("awake_with_sensation"))
            }
        }

        describe("HotFlashAnswers Back→Next regression (FUAM-3511)") {
            // Scenario: on Duration the user taps Back, re-confirms Severity, then
            // Next. The re-confirm must write into `severity`, never into
            // `duration`. Before the fix the nil-cascade wrote it into the first
            // still-nil key (duration) → severity value in duration → 422.
            it("re-confirming Severity never bleeds into duration") {
                var answers = HotFlashAnswers()
                answers.record(step: .severity, selected: ["hot"])   // first confirm
                // Duration screen shown; user goes Back and re-confirms Severity.
                answers.record(step: .severity, selected: ["hot"])   // re-confirm

                expect(answers.severity).to(equal(["hot"]))
                expect(answers.duration).to(beNil(),
                                            description: "the severity value must never land in duration")
            }

            // Analogous one step later: re-confirming Duration must not bleed a
            // duration code into `symptoms`.
            it("re-confirming Duration never bleeds into symptoms") {
                var answers = HotFlashAnswers()
                answers.record(step: .severity, selected: ["hot"])
                answers.record(step: .duration, selected: ["one_to_two_minutes"])  // first confirm
                // Symptoms screen shown; user goes Back and re-confirms Duration.
                answers.record(step: .duration, selected: ["one_to_two_minutes"])  // re-confirm

                expect(answers.duration).to(equal("one_to_two_minutes"))
                expect(answers.symptoms).to(beNil(),
                                            description: "the duration code must never land in symptoms")
                expect(answers.severity).to(equal(["hot"]))
            }

            // A full Back→Next round-trip that changes the answer must overwrite
            // the same key in place, not shift everything down a slot.
            it("editing a re-confirmed step overwrites its own key in place") {
                var answers = HotFlashAnswers()
                answers.record(step: .severity, selected: ["hot"])
                answers.record(step: .duration, selected: ["one_to_two_minutes"])
                // Back to Severity, change the answer, Next again.
                answers.record(step: .severity, selected: ["warm", "sweating"])

                expect(answers.severity).to(equal(["warm", "sweating"]))
                expect(answers.duration).to(equal("one_to_two_minutes"),
                                            description: "an earlier-step edit must not clobber a later answer")
            }
        }
    }
}
