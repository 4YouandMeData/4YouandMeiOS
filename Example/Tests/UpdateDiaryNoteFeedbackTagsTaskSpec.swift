//
//  UpdateDiaryNoteFeedbackTagsTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2934 / FUAM-2939 / FUAM-3857: locks down the PATCH /v2/diary_notes/<id> body shape for
//  feedback_tags_attributes. Round 5 (FUAM-3857) replaced the positional "destroy all but the
//  last, unless it's the sentinel" builder with an explicit one: `feedbackTagsToDestroy` (every
//  server-recorded tag this update removes) and `feedbackTagToSet` (the tag to record, or nil
//  to record none — absence IS "no emoji", there is no sentinel value). These specs pin the
//  three cases the architecture review named — Set, Replace, Clear — plus omission and the
//  never-consult-`label` invariant.
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
                          feedbackTagsToDestroy: [EmojiItem] = [],
                          feedbackTagToSet: EmojiItem? = nil) -> DiaryNoteItem {
                var note = DiaryNoteItem(
                    id: id,
                    type: "diary_note",
                    diaryNoteId: Date(),
                    diaryNoteType: .menstrualPeriod,
                    title: title,
                    body: body,
                    interval: nil
                )
                note.feedbackTagsToDestroy = feedbackTagsToDestroy
                note.feedbackTagToSet = feedbackTagToSet
                return note
            }

            func attributes(for note: DiaryNoteItem) -> [[String: Any]]? {
                let params = unwrapRequestParameters(DefaultService.updateDiaryNoteText(diaryItem: note).task)
                let body = params?["diary_note"] as? [String: Any]
                return body?["feedback_tags_attributes"] as? [[String: Any]]
            }

            it("omits feedback_tags_attributes entirely when nothing is destroyed and nothing is set") {
                let note = makeNote()
                expect(attributes(for: note)).to(beNil())
            }

            // SET — nothing recorded before, a tag is picked. Byte-identical to the
            // pre-refactor builder's output for this case.
            it("SET: records the new tag and destroys nothing") {
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "🥵", label: nil)
                let note = makeNote(feedbackTagToSet: new)

                let result = attributes(for: note)
                expect(result?.count).to(equal(1))
                expect(result?[0]["id"] as? String).to(equal(""))
                expect(result?[0]["tag"] as? String).to(equal("🥵"))
                expect(result?[0]["_destroy"]).to(beNil())
            }

            // REPLACE — an existing tag is destroyed and the new one created, in that order.
            // Byte-identical to the pre-refactor builder's output for this case.
            it("REPLACE: destroys the old record and creates the new one, in that order") {
                let previous = EmojiItem(id: "283", type: "feedback_tag", tag: "🤢", label: nil)
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "🥵", label: nil)
                let note = makeNote(feedbackTagsToDestroy: [previous], feedbackTagToSet: new)

                let result = attributes(for: note)
                expect(result?.count).to(equal(2))
                expect(result?[0]["id"] as? String).to(equal("283"))
                expect(result?[0]["tag"] as? String).to(equal("🤢"))
                expect(result?[0]["_destroy"] as? Bool).to(beTrue())
                expect(result?[1]["id"] as? String).to(equal(""))
                expect(result?[1]["tag"] as? String).to(equal("🥵"))
                expect(result?[1]["_destroy"]).to(beNil())
            }

            // CLEAR — an existing tag is destroyed and nothing is created. This is the one
            // case that is NOT byte-identical to develop: the pre-refactor builder appended an
            // id-less `{"_destroy": true}` element for the sentinel it always had to serialize
            // alongside the real one being destroyed. Rails' `accepts_nested_attributes_for …
            // allow_destroy: true` treats an id-less hash as a NEW record, and `_destroy` on a
            // new record is a no-op — so that trailing element was provably inert; the clear
            // worked through the preceding real `_destroy` entry. Dropping it (there is no
            // sentinel to serialize any more) is strictly smaller, not different in effect.
            it("CLEAR: destroys the old record and creates nothing") {
                let existing = EmojiItem(id: "42", type: "feedback_tag", tag: "😀", label: nil)
                let note = makeNote(feedbackTagsToDestroy: [existing], feedbackTagToSet: nil)

                let result = attributes(for: note)
                expect(result?.count).to(equal(1))
                expect(result?[0]["id"] as? String).to(equal("42"))
                expect(result?[0]["tag"] as? String).to(equal("😀"))
                expect(result?[0]["_destroy"] as? Bool).to(beTrue())
            }

            it("destroys every prior tag when more than one is recorded, and still creates the new one") {
                let firstPrior = EmojiItem(id: "1", type: "feedback_tag", tag: "🤢", label: nil)
                let secondPrior = EmojiItem(id: "2", type: "feedback_tag", tag: "🥵", label: nil)
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "😳", label: nil)
                let note = makeNote(feedbackTagsToDestroy: [firstPrior, secondPrior], feedbackTagToSet: new)

                let result = attributes(for: note)
                expect(result?.count).to(equal(3))
                expect(result?[0]["_destroy"] as? Bool).to(beTrue())
                expect(result?[1]["_destroy"] as? Bool).to(beTrue())
                expect(result?[2]["_destroy"]).to(beNil())
                expect(result?[2]["tag"] as? String).to(equal("😳"))
            }

            // FUAM-3857: the builder never reads `label` — a recorded tag captioned "None" is
            // destroyed and recreated exactly like any other value. There is no sentinel
            // literal left anywhere in this path to key off.
            it("never consults label: a recorded tag captioned 'None' is destroyed-and-recreated like any other") {
                let recordedNone = EmojiItem(id: "77", type: "feedback_tag", tag: "🙂", label: "None")
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "😢", label: nil)
                let note = makeNote(feedbackTagsToDestroy: [recordedNone], feedbackTagToSet: new)

                let result = attributes(for: note)
                expect(result?.count).to(equal(2))
                expect(result?[0]["id"] as? String).to(equal("77"))
                expect(result?[0]["_destroy"] as? Bool).to(beTrue())
                expect(result?[1]["tag"] as? String).to(equal("😢"))
            }

            it("forwards title and body on the PATCH body alongside feedback_tags_attributes") {
                let new = EmojiItem(id: "", type: "feedback_tag", tag: "🥵", label: nil)
                let note = makeNote(title: "T", body: "B", feedbackTagToSet: new)

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
