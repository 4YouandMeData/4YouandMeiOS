//
//  UpdateDiaryNoteFeedbackTagsTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2934 / FUAM-2939: locks down the PATCH /v2/diary_notes/<id> body
//  shape for feedback_tags_attributes — the destroy-all-but-last invariant
//  that drives the "replace previous emoji" behaviour on the menstrual
//  edit form. A regression on this serializer is what caused the BE to
//  accumulate emojis instead of swapping them.
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class UpdateDiaryNoteFeedbackTagsTaskSpec: QuickSpec {
    override class func spec() {
        describe("DefaultService.updateDiaryNoteText feedback_tags_attributes serialization") {

            func makeNote(id: String = "42",
                          title: String? = nil,
                          body: String? = nil,
                          feedbackTags: [EmojiItem]? = nil) -> DiaryNoteItem {
                var note = DiaryNoteItem(
                    id: id,
                    type: "diary_note",
                    diaryNoteId: Date(),
                    diaryNoteType: .menstrualPeriod,
                    title: title,
                    body: body,
                    interval: nil
                )
                note.feedbackTags = feedbackTags
                return note
            }

            it("omits feedback_tags_attributes entirely when feedbackTags is nil") {
                let note = makeNote(feedbackTags: nil)
                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let body = params?["diary_note"] as? [String: Any]
                expect(body?["feedback_tags_attributes"]).to(beNil())
            }

            it("omits feedback_tags_attributes when feedbackTags is empty") {
                let note = makeNote(feedbackTags: [])
                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let body = params?["diary_note"] as? [String: Any]
                expect(body?["feedback_tags_attributes"]).to(beNil())
            }

            it("serializes a single new emoji (id empty) without a destroy directive") {
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "🥵", label: nil)
                let note = makeNote(feedbackTags: [new])

                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let body = params?["diary_note"] as? [String: Any]
                let attributes = body?["feedback_tags_attributes"] as? [[String: Any]]

                expect(attributes?.count).to(equal(1))
                expect(attributes?.first?["id"] as? String).to(equal(""))
                expect(attributes?.first?["tag"] as? String).to(equal("🥵"))
                expect(attributes?.first?["_destroy"]).to(beNil())
            }

            it("marks every prior tag with _destroy:true and keeps the last one") {
                // Replicates the form VC's "append new emoji onto existing tags"
                // pattern after we refetch the entry: previous = server record,
                // appended = new emoji with empty id.
                let previous = EmojiItem(id: "283", type: "feedback_tag", tag: "🤢", label: nil)
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "🥵", label: nil)
                let note = makeNote(feedbackTags: [previous, new])

                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let body = params?["diary_note"] as? [String: Any]
                let attributes = body?["feedback_tags_attributes"] as? [[String: Any]]

                expect(attributes?.count).to(equal(2))
                // First entry — prior server record, marked for destruction.
                expect(attributes?[0]["id"] as? String).to(equal("283"))
                expect(attributes?[0]["tag"] as? String).to(equal("🤢"))
                expect(attributes?[0]["_destroy"] as? Bool).to(beTrue())
                // Last entry — kept (no destroy).
                expect(attributes?[1]["id"] as? String).to(equal(""))
                expect(attributes?[1]["tag"] as? String).to(equal("🥵"))
                expect(attributes?[1]["_destroy"]).to(beNil())
            }

            it("destroys every intermediate tag and only keeps the very last") {
                let a = EmojiItem(id: "1", type: "feedback_tag", tag: "🤢", label: nil)
                let b = EmojiItem(id: "2", type: "feedback_tag", tag: "🥵", label: nil)
                let c = EmojiItem(id: "", type: "feedback_tag", tag: "😳", label: nil)
                let note = makeNote(feedbackTags: [a, b, c])

                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let attributes = (params?["diary_note"] as? [String: Any])?["feedback_tags_attributes"] as? [[String: Any]]

                expect(attributes?.count).to(equal(3))
                expect(attributes?[0]["_destroy"] as? Bool).to(beTrue())
                expect(attributes?[1]["_destroy"] as? Bool).to(beTrue())
                expect(attributes?[2]["_destroy"]).to(beNil())
                expect(attributes?[2]["tag"] as? String).to(equal("😳"))
            }

            it("emits _destroy:true for a 'none' selection (clear-emoji affordance)") {
                // The EmojiPopup ships a sentinel item with label=="none" so the
                // user can clear the current emoji. The serializer must mark it
                // for destruction regardless of position.
                let none = EmojiItem(id: "", type: "", tag: "❌", label: "none")
                let note = makeNote(feedbackTags: [none])

                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let attributes = (params?["diary_note"] as? [String: Any])?["feedback_tags_attributes"] as? [[String: Any]]

                expect(attributes?.count).to(equal(1))
                expect(attributes?[0]["_destroy"] as? Bool).to(beTrue())
            }

            it("forwards title and body on the PATCH body alongside feedback_tags_attributes") {
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "🥵", label: nil)
                let note = makeNote(title: "T", body: "B", feedbackTags: [new])

                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let body = params?["diary_note"] as? [String: Any]

                expect(body?["title"] as? String).to(equal("T"))
                expect(body?["body"] as? String).to(equal("B"))
                expect(body?["feedback_tags_attributes"]).toNot(beNil())
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
