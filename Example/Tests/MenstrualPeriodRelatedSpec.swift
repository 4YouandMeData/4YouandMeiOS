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
            it("maps no → bleeding.no") {
                expect(MenstrualPeriodRelated.no.bleeding).to(equal(MenstrualBleeding.no))
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
    }
}
