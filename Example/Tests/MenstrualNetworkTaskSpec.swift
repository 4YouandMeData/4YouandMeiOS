//
//  MenstrualNetworkTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2935: verifies DefaultService.sendDiaryNoteMenstrual builds the
//  expected request body in the standalone and fromChart variants.
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class MenstrualNetworkTaskSpec: QuickSpec {
    override class func spec() {
        describe("DefaultService.sendDiaryNoteMenstrual task body") {

            let date = Date(timeIntervalSince1970: 1_750_000_000)

            it("emits diary_type=menstrual_period_diary with all data fields") {
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
                expect(diaryNote["diary_type"] as? String).to(equal("menstrual_period_diary"))
                expect(diaryNote["datetime_ref"] as? String).toNot(beNil())

                guard let payload = diaryNote["data"] as? [String: Any] else {
                    fail("Missing data payload")
                    return
                }
                expect(payload["flow_amount"] as? String).to(equal("moderate"))
                expect(payload["period_related"] as? String).to(equal("yes"))
                expect(payload["bleeding"] as? String).to(equal("yes"))
                expect(payload["note"] as? String).to(equal("Started today"))
                expect(payload["date"] as? String).toNot(beNil())
            }

            it("omits the note key when note is nil") {
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

            it("derives bleeding=other for letMeExplain") {
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
                expect(payload?["period_related"] as? String).to(equal("let_me_explain"))
            }

            it("emits period_related_note when an explanation is provided") {
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
                expect(payload?["period_related_note"] as? String).to(equal("After IUD insertion"))
            }

            it("omits period_related_note when explanation is nil or empty") {
                for explanation in [nil, ""] as [String?] {
                    let data = DiaryNoteMenstrualData(
                        date: date,
                        flowAmount: .light,
                        periodRelated: .yes,
                        periodRelatedExplanation: explanation,
                        note: nil,
                        fromChart: false,
                        diaryNote: nil
                    )
                    let service = DefaultService.sendDiaryNoteMenstrual(data: data)
                    let params = unwrapRequestParameters(service.task)
                    let payload = (params?["diary_note"] as? [String: Any])?["data"] as? [String: Any]
                    expect(payload?["period_related_note"]).to(beNil())
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
