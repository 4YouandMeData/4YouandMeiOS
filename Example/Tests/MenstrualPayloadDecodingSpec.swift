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

        // FUAM-2934 — BE v0.12.5 series grouping. `series_meta` is a top-level
        // attribute (after JSON:API flattening); `series_entries` is the
        // sideloaded relationship, surfacing as a nested array of diary notes.
        describe("DiaryNoteItem series grouping (FUAM-2934)") {

            it("decodes series_meta with from/to/ongoing/count on a closed series") {
                let json = """
                {
                    "id": "1234",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-05T00:00:00.000Z",
                    "diary_type": "menstrual_period",
                    "data": { "date": "2026-04-05T00:00:00.000Z", "flow": 2, "period_related": "yes", "bleeding": "yes" },
                    "series_meta": { "from": "2026-04-01", "to": "2026-04-05", "ongoing": false, "count": 4 }
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item?.seriesMeta).toNot(beNil())
                let meta = item?.seriesMeta
                expect(meta?.ongoing).to(beFalse())
                expect(meta?.count).to(equal(4))
                expect(meta.map { MenstrualSeriesMeta.dateFormatter.string(from: $0.from) }).to(equal("2026-04-01"))
                expect(meta?.to).toNot(beNil())
                expect(meta.flatMap { $0.to }.map { MenstrualSeriesMeta.dateFormatter.string(from: $0) }).to(equal("2026-04-05"))
            }

            it("decodes series_meta with to=null when the series is ongoing") {
                let json = """
                {
                    "id": "1234",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-05T00:00:00.000Z",
                    "diary_type": "menstrual_period",
                    "data": { "date": "2026-04-05T00:00:00.000Z", "flow": 2, "period_related": "yes", "bleeding": "yes" },
                    "series_meta": { "from": "2026-04-01", "to": null, "ongoing": true, "count": 5 }
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item?.seriesMeta?.ongoing).to(beTrue())
                expect(item?.seriesMeta?.to).to(beNil())
                expect(item?.seriesMeta?.count).to(equal(5))
            }

            it("decodes series_entries as the chronological member list") {
                let json = """
                {
                    "id": "1234",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-05T00:00:00.000Z",
                    "diary_type": "menstrual_period",
                    "data": { "date": "2026-04-05T00:00:00.000Z", "flow": 2, "period_related": "yes", "bleeding": "yes" },
                    "series_meta": { "from": "2026-04-01", "to": "2026-04-05", "ongoing": false, "count": 2 },
                    "series_entries": [
                        { "id": "1230", "type": "diary_note", "datetime_ref": "2026-04-01T00:00:00.000Z", "diary_type": "menstrual_period", "data": { "date": "2026-04-01T00:00:00.000Z", "flow": 1, "period_related": "yes", "bleeding": "yes" } },
                        { "id": "1234", "type": "diary_note", "datetime_ref": "2026-04-05T00:00:00.000Z", "diary_type": "menstrual_period", "data": { "date": "2026-04-05T00:00:00.000Z", "flow": 2, "period_related": "yes", "bleeding": "yes" } }
                    ]
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item?.seriesEntries?.count).to(equal(2))
                expect(item?.seriesEntries?.map { $0.id }).to(equal(["1230", "1234"]))
                // Members carry their own menstrual payload but no nested series.
                expect(item?.seriesEntries?.first?.diaryNoteType).to(equal(.menstrualPeriod))
                expect(item?.seriesEntries?.first?.seriesMeta).to(beNil())
            }

            it("leaves series fields nil on a row without grouping (closing 'no' / orphan 'other')") {
                let json = """
                {
                    "id": "9",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-06T00:00:00.000Z",
                    "diary_type": "menstrual_period",
                    "data": { "date": "2026-04-06T00:00:00.000Z", "flow": 0, "period_related": "not_sure", "bleeding": "no" }
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item).toNot(beNil())
                expect(item?.seriesMeta).to(beNil())
                expect(item?.seriesEntries).to(beNil())
            }
        }
    }
}
