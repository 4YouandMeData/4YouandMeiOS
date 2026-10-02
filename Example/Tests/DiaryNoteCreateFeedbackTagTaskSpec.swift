//
//  DiaryNoteCreateFeedbackTagTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4255 — An emoji picked before a diary text note exists must ride IN
//  the create request itself: `feedback_tags_attributes: [{ "tag": ... }]`,
//  matching the backend's `create_diary_note_params` (which permits only
//  `:tag`, not `:id`/`:_destroy` — those are update-only). Never a follow-up
//  PATCH against a client-generated id.
//
//  Covers both create encodings used by `DefaultService.sendDiaryNoteText`:
//  - fromChart == true: manual `.requestParameters` body (chart-linked note);
//  - fromChart == false: `.requestJSONEncodable(diaryNote)` (Diary-tab/FAB note).
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class DiaryNoteCreateFeedbackTagTaskSpec: QuickSpec {
    override class func spec() {
        describe("DefaultService.sendDiaryNoteText task body") {

            context("fromChart == true (chart-linked note, manual params)") {

                it("includes feedback_tags_attributes: [{tag: ...}] when an emoji is held") {
                    var note = DiaryNoteItem(date: Date(),
                                             body: "",
                                             interval: "day",
                                             diaryNoteable: DiaryNoteable(id: "12", type: "chart"))
                    note.feedbackTagToSet = EmojiItem(id: "", type: "feedback_tag", tag: "😀", label: nil)

                    let service = DefaultService.sendDiaryNoteText(diaryItem: note, fromChart: true)
                    let params = unwrapRequestParameters(service.task)
                    let diaryNote = params?["diary_note"] as? [String: Any]
                    let attributes = diaryNote?["feedback_tags_attributes"] as? [[String: Any]]

                    expect(attributes?.count).to(equal(1))
                    expect(attributes?.first?["tag"] as? String).to(equal("😀"))
                    // Create-only payload: no id/_destroy keys (those are PATCH-only).
                    expect(attributes?.first?["id"]).to(beNil())
                    expect(attributes?.first?["_destroy"]).to(beNil())
                }

                it("omits feedback_tags_attributes entirely when no emoji is held") {
                    let note = DiaryNoteItem(date: Date(),
                                             body: "",
                                             interval: "day",
                                             diaryNoteable: DiaryNoteable(id: "12", type: "chart"))

                    let service = DefaultService.sendDiaryNoteText(diaryItem: note, fromChart: true)
                    let params = unwrapRequestParameters(service.task)
                    let diaryNote = params?["diary_note"] as? [String: Any]

                    expect(diaryNote?["feedback_tags_attributes"]).to(beNil())
                }
            }

            context("fromChart == false (Diary-tab/FAB note, JSON-encodable body)") {

                it("includes feedback_tags_attributes: [{tag: ...}] when an emoji is held") {
                    var note = DiaryNoteItem(diaryNoteId: nil, body: "Hello", interval: nil, diaryNoteable: nil)
                    note.feedbackTagToSet = EmojiItem(id: "", type: "feedback_tag", tag: "🥵", label: nil)

                    let service = DefaultService.sendDiaryNoteText(diaryItem: note, fromChart: false)
                    let body = unwrapRequestJSONEncodableBody(service.task)
                    let attributes = body?["feedback_tags_attributes"] as? [[String: Any]]

                    expect(attributes?.count).to(equal(1))
                    expect(attributes?.first?["tag"] as? String).to(equal("🥵"))
                    expect(attributes?.first?["id"]).to(beNil())
                    expect(attributes?.first?["_destroy"]).to(beNil())
                }

                it("omits feedback_tags_attributes entirely when no emoji is held") {
                    let note = DiaryNoteItem(diaryNoteId: nil, body: "Hello", interval: nil, diaryNoteable: nil)

                    let service = DefaultService.sendDiaryNoteText(diaryItem: note, fromChart: false)
                    let body = unwrapRequestJSONEncodableBody(service.task)

                    expect(body?["feedback_tags_attributes"]).to(beNil())
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

private func unwrapRequestJSONEncodableBody(_ task: Task) -> [String: Any]? {
    guard case let .requestJSONEncodable(encodable) = task,
          let data = try? JSONEncoder().encode(encodable),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    return json
}
