//
//  MenstrualNetworkTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2935 / FUAM-2925: verifies DefaultService.sendDiaryNoteMenstrual
//  builds the body matching the BE JSON Schema (flow integer 0-4,
//  period_related yes/no/not_sure/other, optional note ≤ 2500 chars).
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class MenstrualNetworkTaskSpec: QuickSpec {
    override class func spec() {
        describe("DefaultService.sendDiaryNoteMenstrual task body") {

            let date = Date(timeIntervalSince1970: 1_750_000_000)

            it("emits diary_type=menstrual_period with all data fields") {
                let data = DiaryNoteMenstrualData(
                    date: date,
                    flowAmount: .moderate,
                    periodRelated: .yes,
                    periodRelatedExplanation: nil,
                    note: "Started today",
                    fromChart: false,
                    diaryNote: nil
                )
                let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                let params = unwrapRequestParameters(service.task)

                guard let diaryNote = params?["diary_note"] as? [String: Any] else {
                    fail("Missing diary_note wrapper in body: \(String(describing: params))")
                    return
                }
                expect(diaryNote["diary_type"] as? String).to(equal("menstrual_period"))
                expect(diaryNote["datetime_ref"] as? String).toNot(beNil())

                guard let payload = diaryNote["data"] as? [String: Any] else {
                    fail("Missing data payload")
                    return
                }
                expect(payload["flow"] as? Int).to(equal(2))
                expect(payload["period_related"] as? String).to(equal("yes"))
                expect(payload["bleeding"] as? String).to(equal("yes"))
                expect(payload["note"] as? String).to(equal("Started today"))
                expect(payload["date"]).to(beNil())
                expect(payload["flow_amount"]).to(beNil())
                expect(payload["period_related_note"]).to(beNil())
            }

            it("encodes flow as integer 0..4 across all flow amounts") {
                let mapping: [(MenstrualFlowAmount, Int)] = [
                    (.spotting, 0),
                    (.light, 1),
                    (.moderate, 2),
                    (.heavy, 3),
                    (.veryHeavy, 4)
                ]
                for (amount, expected) in mapping {
                    let data = DiaryNoteMenstrualData(
                        date: date,
                        flowAmount: amount,
                        periodRelated: .yes,
                        periodRelatedExplanation: nil,
                        note: nil,
                        fromChart: false,
                        diaryNote: nil
                    )
                    let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                    let params = unwrapRequestParameters(service.task)
                    let payload = (params?["diary_note"] as? [String: Any])?["data"] as? [String: Any]
                    expect(payload?["flow"] as? Int).to(equal(expected))
                }
            }

            it("omits the note key when note is nil and no explanation") {
                let data = DiaryNoteMenstrualData(
                    date: date,
                    flowAmount: .spotting,
                    periodRelated: .notSure,
                    periodRelatedExplanation: nil,
                    note: nil,
                    fromChart: false,
                    diaryNote: nil
                )
                let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                let params = unwrapRequestParameters(service.task)
                let diaryNote = params?["diary_note"] as? [String: Any]
                let payload = diaryNote?["data"] as? [String: Any]

                expect(payload?["note"]).to(beNil())
                expect(payload?["bleeding"] as? String).to(equal("other"))
                expect(payload?["period_related"] as? String).to(equal("not_sure"))
            }

            it("omits the note key when note is empty string") {
                let data = DiaryNoteMenstrualData(
                    date: date,
                    flowAmount: .light,
                    periodRelated: .no,
                    periodRelatedExplanation: nil,
                    note: "",
                    fromChart: false,
                    diaryNote: nil
                )
                let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                let params = unwrapRequestParameters(service.task)
                let diaryNote = params?["diary_note"] as? [String: Any]
                let payload = diaryNote?["data"] as? [String: Any]

                expect(payload?["note"]).to(beNil())
                expect(payload?["bleeding"] as? String).to(equal("no"))
            }

            it("maps letMeExplain to period_related=other (BE schema)") {
                let data = DiaryNoteMenstrualData(
                    date: date,
                    flowAmount: .heavy,
                    periodRelated: .letMeExplain,
                    periodRelatedExplanation: nil,
                    note: "Heavy after IUD",
                    fromChart: false,
                    diaryNote: nil
                )
                let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                let params = unwrapRequestParameters(service.task)
                let payload = (params?["diary_note"] as? [String: Any])?["data"] as? [String: Any]
                expect(payload?["bleeding"] as? String).to(equal("other"))
                expect(payload?["period_related"] as? String).to(equal("other"))
                expect(payload?["note"] as? String).to(equal("Heavy after IUD"))
            }

            it("uses explanation as note when only explanation is present") {
                let data = DiaryNoteMenstrualData(
                    date: date,
                    flowAmount: .heavy,
                    periodRelated: .letMeExplain,
                    periodRelatedExplanation: "After IUD insertion",
                    note: nil,
                    fromChart: false,
                    diaryNote: nil
                )
                let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                let params = unwrapRequestParameters(service.task)
                let payload = (params?["diary_note"] as? [String: Any])?["data"] as? [String: Any]
                expect(payload?["note"] as? String).to(equal("After IUD insertion"))
            }

            it("concatenates explanation and user note with a blank line") {
                let data = DiaryNoteMenstrualData(
                    date: date,
                    flowAmount: .heavy,
                    periodRelated: .letMeExplain,
                    periodRelatedExplanation: "After IUD insertion",
                    note: "Heavy after IUD",
                    fromChart: false,
                    diaryNote: nil
                )
                let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                let params = unwrapRequestParameters(service.task)
                let payload = (params?["diary_note"] as? [String: Any])?["data"] as? [String: Any]
                expect(payload?["note"] as? String).to(equal("After IUD insertion\n\nHeavy after IUD"))
            }

            it("truncates note to 2500 characters") {
                let long = String(repeating: "a", count: 3000)
                let data = DiaryNoteMenstrualData(
                    date: date,
                    flowAmount: .light,
                    periodRelated: .yes,
                    periodRelatedExplanation: nil,
                    note: long,
                    fromChart: false,
                    diaryNote: nil
                )
                let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                let params = unwrapRequestParameters(service.task)
                let payload = (params?["diary_note"] as? [String: Any])?["data"] as? [String: Any]
                expect((payload?["note"] as? String)?.count).to(equal(2500))
            }

            it("omits note when both explanation and user note are nil or empty") {
                let combos: [(String?, String?)] = [
                    (nil, nil),
                    ("", ""),
                    (nil, ""),
                    ("", nil)
                ]
                for (exp, note) in combos {
                    let data = DiaryNoteMenstrualData(
                        date: date,
                        flowAmount: .light,
                        periodRelated: .yes,
                        periodRelatedExplanation: exp,
                        note: note,
                        fromChart: false,
                        diaryNote: nil
                    )
                    let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                    let params = unwrapRequestParameters(service.task)
                    let payload = (params?["diary_note"] as? [String: Any])?["data"] as? [String: Any]
                    expect(payload?["note"]).to(beNil())
                }
            }
        }
    }
}

// MARK: - Helpers

private func unwrapRequestParameters(_ task: Task) -> [String: Any]? {
    if case let .requestParameters(parameters, _) = task {
        return parameters
    }
    return nil
}
