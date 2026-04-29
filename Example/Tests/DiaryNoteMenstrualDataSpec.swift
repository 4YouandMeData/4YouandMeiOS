//
//  DiaryNoteMenstrualDataSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2935: verifies DiaryNoteMenstrualData wires bleeding through the
//  selected periodRelated answer and preserves the rest of the wizard state.
//

import Quick
import Nimble
@testable import ForYouAndMe

class DiaryNoteMenstrualDataSpec: QuickSpec {
    override class func spec() {
        describe("DiaryNoteMenstrualData") {

            it("derives bleeding from periodRelated.yes") {
                let data = DiaryNoteMenstrualData(
                    date: Date(timeIntervalSince1970: 1_750_000_000),
                    flowAmount: .light,
                    periodRelated: .yes,
                    note: nil,
                    fromChart: false,
                    diaryNote: nil
                )
                expect(data.bleeding).to(equal(.yes))
            }

            it("derives bleeding from periodRelated.no") {
                let data = DiaryNoteMenstrualData(
                    date: Date(),
                    flowAmount: .moderate,
                    periodRelated: .no,
                    note: "spotting after exercise",
                    fromChart: false,
                    diaryNote: nil
                )
                expect(data.bleeding).to(equal(.no))
                expect(data.note).to(equal("spotting after exercise"))
            }

            it("derives bleeding=other for notSure and letMeExplain") {
                let notSure = DiaryNoteMenstrualData(
                    date: Date(),
                    flowAmount: .heavy,
                    periodRelated: .notSure,
                    note: nil,
                    fromChart: false,
                    diaryNote: nil)
                let explain = DiaryNoteMenstrualData(
                    date: Date(),
                    flowAmount: .veryHeavy,
                    periodRelated: .letMeExplain,
                    note: "after IUD insertion",
                    fromChart: true,
                    diaryNote: nil)
                expect(notSure.bleeding).to(equal(.other))
                expect(explain.bleeding).to(equal(.other))
            }

            it("preserves fromChart flag") {
                let chart = DiaryNoteMenstrualData(
                    date: Date(),
                    flowAmount: .spotting,
                    periodRelated: .yes,
                    note: nil,
                    fromChart: true,
                    diaryNote: nil)
                expect(chart.fromChart).to(beTrue())
            }
        }
    }
}
