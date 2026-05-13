//
//  HotFlashAdditionalStepsTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3247: locks down the sendDiaryNoteHotFlash POST body so the new
//  severity / duration / symptoms / sleep_onset answers only ship under
//  `data` when the extended flow actually ran. Empty/nil collections must
//  not leak the keys to the BE so legacy entries keep their old shape.
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class HotFlashAdditionalStepsTaskSpec: QuickSpec {
    override class func spec() {
        describe("DefaultService.sendDiaryNoteHotFlash data payload") {

            let date = Date(timeIntervalSince1970: 1_750_000_000)

            it("omits `data` entirely when no additional-step answers are set (legacy flow)") {
                let data = DiaryNoteHotFlashData(date: date, fromChart: false, diaryNote: nil)
                let body = unwrapDiaryNote(.sendDiaryNoteHotFlash(data: data))
                expect(body?["data"]).to(beNil(),
                                        description: "legacy entries must not include `data` to preserve BE backward-compat")
                expect(body?["datetime_ref"] as? String).toNot(beNil())
                expect(body?["diary_type"] as? String).to(equal("hot_flash_diary"))
            }

            it("nests every populated field under `data` with the BE-bound key names") {
                let data = DiaryNoteHotFlashData(
                    date: date,
                    fromChart: false,
                    diaryNote: nil,
                    severity: ["warm", "hot"],
                    duration: "1_to_2_minutes",
                    symptoms: ["anxiety", "panic"],
                    sleepOnset: "before_wake"
                )
                let body = unwrapDiaryNote(.sendDiaryNoteHotFlash(data: data))
                let payload = body?["data"] as? [String: Any]

                expect(payload?["severity"] as? [String]).to(equal(["warm", "hot"]))
                expect(payload?["duration"] as? String).to(equal("1_to_2_minutes"))
                expect(payload?["symptoms"] as? [String]).to(equal(["anxiety", "panic"]))
                expect(payload?["sleep_onset"] as? String).to(equal("before_wake"))
            }

            it("skips empty arrays so an unselected multi-step doesn't reach the BE") {
                let data = DiaryNoteHotFlashData(
                    date: date,
                    fromChart: false,
                    diaryNote: nil,
                    severity: [],            // empty → omit
                    duration: "less_than_minute",
                    symptoms: nil,           // nil → omit
                    sleepOnset: nil
                )
                let body = unwrapDiaryNote(.sendDiaryNoteHotFlash(data: data))
                let payload = body?["data"] as? [String: Any]

                expect(payload?["severity"]).to(beNil())
                expect(payload?["symptoms"]).to(beNil())
                expect(payload?["sleep_onset"]).to(beNil())
                expect(payload?["duration"] as? String).to(equal("less_than_minute"))
            }

            it("skips empty string for the single-select fields") {
                let data = DiaryNoteHotFlashData(
                    date: date,
                    fromChart: false,
                    diaryNote: nil,
                    severity: ["warm"],
                    duration: "",
                    symptoms: ["anxiety"],
                    sleepOnset: ""
                )
                let body = unwrapDiaryNote(.sendDiaryNoteHotFlash(data: data))
                let payload = body?["data"] as? [String: Any]

                expect(payload?["duration"]).to(beNil())
                expect(payload?["sleep_onset"]).to(beNil())
                expect(payload?["severity"] as? [String]).to(equal(["warm"]))
                expect(payload?["symptoms"] as? [String]).to(equal(["anxiety"]))
            }

            it("ships `data` even when only one field is populated") {
                let data = DiaryNoteHotFlashData(
                    date: date,
                    fromChart: false,
                    diaryNote: nil,
                    severity: ["sweating"]
                )
                let body = unwrapDiaryNote(.sendDiaryNoteHotFlash(data: data))
                let payload = body?["data"] as? [String: Any]

                expect(payload).toNot(beNil())
                expect(payload?["severity"] as? [String]).to(equal(["sweating"]))
                expect(payload?["duration"]).to(beNil())
                expect(payload?["symptoms"]).to(beNil())
                expect(payload?["sleep_onset"]).to(beNil())
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

private func unwrapDiaryNote(_ service: DefaultService) -> [String: Any]? {
    return unwrapRequestParameters(service.task)?["diary_note"] as? [String: Any]
}
