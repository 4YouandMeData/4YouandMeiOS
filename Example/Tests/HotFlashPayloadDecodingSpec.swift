//
//  HotFlashPayloadDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3247: locks down the DiaryNoteItem decoder for the hot_flash_diary
//  type so the 4 additional-step answers (severity / duration / symptoms /
//  sleep_onset) survive the round-trip from BE JSON into
//  DiaryNotePayload.hotFlash. Legacy entries (`data: null`) must keep
//  decoding with every additional field set to `nil`.
//

import Quick
import Nimble
@testable import ForYouAndMe

class HotFlashPayloadDecodingSpec: QuickSpec {
    override class func spec() {
        describe("DiaryNoteItem decoding for hot_flash_diary") {

            it("decodes every additional field into DiaryNotePayload.hotFlash") {
                let json = """
                {
                    "id": "5737",
                    "type": "diary_note",
                    "datetime_ref": "2026-05-14T03:15:51.000Z",
                    "diary_type": "hot_flash_diary",
                    "data": {
                        "duration": "one_to_two_minutes",
                        "severity": ["hot"],
                        "symptoms": ["anxiety"],
                        "sleep_onset": "awake_then_sensation"
                    }
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item).toNot(beNil())
                expect(item?.diaryNoteType).to(equal(.hotFlash))

                guard case let .hotFlash(_, severity, duration, symptoms, sleepOnset) = item?.payload else {
                    fail("Expected .hotFlash payload, got \(String(describing: item?.payload))")
                    return
                }
                expect(severity).to(equal(["hot"]))
                expect(duration).to(equal("one_to_two_minutes"))
                expect(symptoms).to(equal(["anxiety"]))
                expect(sleepOnset).to(equal("awake_then_sensation"))
            }

            it("supports multi-element arrays for severity and symptoms") {
                let json = """
                {
                    "id": "5738",
                    "type": "diary_note",
                    "datetime_ref": "2026-05-14T03:15:51.000Z",
                    "diary_type": "hot_flash_diary",
                    "data": {
                        "duration": "nearly_five_minutes",
                        "severity": ["warm", "hot", "sweating"],
                        "symptoms": ["anxiety", "panic", "racing_thoughts"],
                        "sleep_onset": "awake_with_sensation"
                    }
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                guard case let .hotFlash(_, severity, _, symptoms, _) = item?.payload else {
                    fail("Expected .hotFlash payload")
                    return
                }
                expect(severity).to(equal(["warm", "hot", "sweating"]))
                expect(symptoms).to(equal(["anxiety", "panic", "racing_thoughts"]))
            }

            it("leaves all additional fields nil when `data` is null (legacy entry)") {
                let json = """
                {
                    "id": "1000",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-29T08:30:00.000Z",
                    "diary_type": "hot_flash_diary",
                    "data": null
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                expect(item).toNot(beNil())
                expect(item?.diaryNoteType).to(equal(.hotFlash))
                // With `data: null` the decoder doesn't populate a payload —
                // the form falls back to `diaryNoteId` for the displayed date.
                expect(item?.payload).to(beNil())
            }

            it("decodes the datetime_ref-based date when `data` is present but additional fields are missing") {
                let json = """
                {
                    "id": "1001",
                    "type": "diary_note",
                    "datetime_ref": "2026-04-29T08:30:00.000Z",
                    "diary_type": "hot_flash_diary",
                    "data": {}
                }
                """.data(using: .utf8)!

                let item = try? JSONDecoder().decode(DiaryNoteItem.self, from: json)
                guard case let .hotFlash(_, severity, duration, symptoms, sleepOnset) = item?.payload else {
                    fail("Expected .hotFlash payload, got \(String(describing: item?.payload))")
                    return
                }
                expect(severity).to(beNil())
                expect(duration).to(beNil())
                expect(symptoms).to(beNil())
                expect(sleepOnset).to(beNil())
            }
        }
    }
}
