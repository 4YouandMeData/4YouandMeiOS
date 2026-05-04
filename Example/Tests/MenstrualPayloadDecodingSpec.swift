//
//  MenstrualPayloadDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2925 / FUAM-2935: verifies the DiaryNoteItem decoder routes payloads
//  with diary_type=menstrual_period into DiaryNotePayload.menstrual using the
//  real BE schema (flow as Int 0..4, mapped back to MenstrualFlowAmount.rawValue).
//

import Quick
import Nimble
@testable import ForYouAndMe

class MenstrualPayloadDecodingSpec: QuickSpec {
    override class func spec() {
        describe("DiaryNoteItem decoding for menstrual_period") {

            it("decodes all menstrual fields into DiaryNotePayload.menstrual") {
                let json = """
                {
                    "id": "1",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-29T08:30:00.000Z",
                    "diary_type": "menstrual_period",
                    "data": {
                        "date": "2026-04-29T08:30:00.000Z",
                        "flow": 2,
                        "period_related": "yes",
                        "bleeding": "yes",
                        "note": "Started this morning"
                    }
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item).toNot(beNil())
                expect(item?.diaryNoteType).to(equal(.menstrualPeriod))

                guard case let .menstrual(date, flowAmount, periodRelated, bleeding, note) = item?.payload else {
                    fail("Expected .menstrual payload, got \(String(describing: item?.payload))")
                    return
                }
                expect(date).toNot(beNil())
                expect(flowAmount).to(equal(MenstrualFlowAmount.moderate.rawValue))
                expect(periodRelated).to(equal("yes"))
                expect(bleeding).to(equal("yes"))
                expect(note).to(equal("Started this morning"))
            }

            it("decodes payload with no note (nil)") {
                let json = """
                {
                    "id": "2",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-28T12:00:00.000Z",
                    "diary_type": "menstrual_period",
                    "data": {
                        "date": "2026-04-28T12:00:00.000Z",
                        "flow": 0,
                        "period_related": "not_sure",
                        "bleeding": "other"
                    }
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item).toNot(beNil())

                guard case let .menstrual(_, flow, related, bleeding, note) = item?.payload else {
                    fail("Expected .menstrual payload")
                    return
                }
                expect(flow).to(equal(MenstrualFlowAmount.spotting.rawValue))
                expect(related).to(equal("not_sure"))
                expect(bleeding).to(equal("other"))
                expect(note).to(beNil())
            }

            it("maps every flow integer 0..4 to the matching MenstrualFlowAmount") {
                let cases: [(Int, MenstrualFlowAmount)] = [
                    (0, .spotting),
                    (1, .light),
                    (2, .moderate),
                    (3, .heavy),
                    (4, .veryHeavy)
                ]
                for (intValue, expected) in cases {
                    let json = """
                    {
                        "id": "n\(intValue)",
                        "type": "diary_note",
                        "datetime_ref": "2026-04-28T12:00:00.000Z",
                        "diary_type": "menstrual_period",
                        "data": {
                            "date": "2026-04-28T12:00:00.000Z",
                            "flow": \(intValue),
                            "period_related": "yes",
                            "bleeding": "yes"
                        }
                    }
                    """.data(using: .utf8)!
                    let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                    guard case let .menstrual(_, flow, _, _, _) = item?.payload else {
                        fail("Expected .menstrual payload for flow=\(intValue)")
                        return
                    }
                    expect(flow).to(equal(expected.rawValue))
                }
            }
        }
    }
}
