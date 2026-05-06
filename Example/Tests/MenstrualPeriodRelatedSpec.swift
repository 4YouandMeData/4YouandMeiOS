//
//  MenstrualPeriodRelatedSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2935: verifies the bleeding field is derived correctly from the
//  user's "Was this related to a menstrual period?" answer.
//

import Quick
import Nimble
@testable import ForYouAndMe

class MenstrualPeriodRelatedSpec: QuickSpec {
    override class func spec() {
        describe("MenstrualPeriodRelated.bleeding mapping") {
            it("maps yes → bleeding.yes") {
                expect(MenstrualPeriodRelated.yes.bleeding).to(equal(MenstrualBleeding.yes))
            }
            it("maps no → bleeding.other (wizard collapses non-yes answers)") {
                // Wizard semantics: only periodRelated=.yes reports actual
                // bleeding. The bleeding="no" value is reserved for the
                // FUAM-2932 feed-alert "No" shortcut, not the wizard step.
                expect(MenstrualPeriodRelated.no.bleeding).to(equal(MenstrualBleeding.other))
            }
            it("maps notSure → bleeding.other") {
                expect(MenstrualPeriodRelated.notSure.bleeding).to(equal(MenstrualBleeding.other))
            }
            it("maps letMeExplain → bleeding.other") {
                expect(MenstrualPeriodRelated.letMeExplain.bleeding).to(equal(MenstrualBleeding.other))
            }
        }

        describe("MenstrualPeriodRelated raw values") {
            it("matches the contract expected by backend") {
                expect(MenstrualPeriodRelated.yes.rawValue).to(equal("yes"))
                expect(MenstrualPeriodRelated.no.rawValue).to(equal("no"))
                expect(MenstrualPeriodRelated.notSure.rawValue).to(equal("not_sure"))
                expect(MenstrualPeriodRelated.letMeExplain.rawValue).to(equal("let_me_explain"))
            }
        }

        describe("MenstrualFlowAmount raw values") {
            it("matches the contract expected by backend") {
                expect(MenstrualFlowAmount.spotting.rawValue).to(equal("spotting"))
                expect(MenstrualFlowAmount.light.rawValue).to(equal("light"))
                expect(MenstrualFlowAmount.moderate.rawValue).to(equal("moderate"))
                expect(MenstrualFlowAmount.heavy.rawValue).to(equal("heavy"))
                expect(MenstrualFlowAmount.veryHeavy.rawValue).to(equal("very_heavy"))
            }
        }

        describe("FUAM-2925 backend value mappings") {
            it("encodes flow as integer 0..4") {
                expect(MenstrualFlowAmount.spotting.intValue).to(equal(0))
                expect(MenstrualFlowAmount.light.intValue).to(equal(1))
                expect(MenstrualFlowAmount.moderate.intValue).to(equal(2))
                expect(MenstrualFlowAmount.heavy.intValue).to(equal(3))
                expect(MenstrualFlowAmount.veryHeavy.intValue).to(equal(4))
            }
            it("collapses period_related letMeExplain to other") {
                expect(MenstrualPeriodRelated.yes.backendValue).to(equal("yes"))
                expect(MenstrualPeriodRelated.no.backendValue).to(equal("no"))
                expect(MenstrualPeriodRelated.notSure.backendValue).to(equal("not_sure"))
                expect(MenstrualPeriodRelated.letMeExplain.backendValue).to(equal("other"))
            }
        }

        describe("MenstrualFlowAmount(intValue:) — BE response decoding") {
            it("maps every BE integer 0..4 to the matching enum case") {
                expect(MenstrualFlowAmount(intValue: 0)).to(equal(.spotting))
                expect(MenstrualFlowAmount(intValue: 1)).to(equal(.light))
                expect(MenstrualFlowAmount(intValue: 2)).to(equal(.moderate))
                expect(MenstrualFlowAmount(intValue: 3)).to(equal(.heavy))
                expect(MenstrualFlowAmount(intValue: 4)).to(equal(.veryHeavy))
            }
            it("returns nil for out-of-range integers") {
                expect(MenstrualFlowAmount(intValue: -1)).to(beNil())
                expect(MenstrualFlowAmount(intValue: 5)).to(beNil())
                expect(MenstrualFlowAmount(intValue: 42)).to(beNil())
            }
            it("is round-trip safe with intValue") {
                for amount in MenstrualFlowAmount.allCases {
                    expect(MenstrualFlowAmount(intValue: amount.intValue)).to(equal(amount))
                }
            }
        }

        describe("MenstrualPeriodRelated(backendValue:) — BE response decoding") {
            it("maps yes/no/not_sure/let_me_explain to themselves") {
                expect(MenstrualPeriodRelated(backendValue: "yes")).to(equal(.yes))
                expect(MenstrualPeriodRelated(backendValue: "no")).to(equal(.no))
                expect(MenstrualPeriodRelated(backendValue: "not_sure")).to(equal(.notSure))
                expect(MenstrualPeriodRelated(backendValue: "let_me_explain")).to(equal(.letMeExplain))
            }
            it("maps BE other → letMeExplain (inverse of backendValue collapse)") {
                expect(MenstrualPeriodRelated(backendValue: "other")).to(equal(.letMeExplain))
            }
            it("returns nil for unknown values") {
                expect(MenstrualPeriodRelated(backendValue: "")).to(beNil())
                expect(MenstrualPeriodRelated(backendValue: "maybe")).to(beNil())
                expect(MenstrualPeriodRelated(backendValue: "YES")).to(beNil())
            }
            it("round-trips through backendValue for non-letMeExplain cases") {
                let cases: [MenstrualPeriodRelated] = [.yes, .no, .notSure]
                for value in cases {
                    expect(MenstrualPeriodRelated(backendValue: value.backendValue)).to(equal(value))
                }
                // letMeExplain is intentionally lossy on send (collapses to "other"),
                // and the inverse decoder restores it.
                expect(MenstrualPeriodRelated(backendValue: MenstrualPeriodRelated.letMeExplain.backendValue))
                    .to(equal(.letMeExplain))
            }
        }
    }
}
