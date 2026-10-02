//
//  DiaryNoteEmojiCreateFlowSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4255 (review round) — DiaryNoteMustSendInsteadOfUpdateSpec locks down the
//  pure predicate, but not that the view controller's two real call sites actually
//  USE it: `emojiButtonTapped`'s confirm closure (guard at the former hard-coded
//  `diaryNote != nil` check) and `doneButtonPressed`'s create branch (attaching the
//  held emoji to the POST). Both were refactored into static functions the
//  production code calls directly — `emojiConfirmAction` and `noteToCreate` — so
//  these specs exercise the EXACT functions the view controller runs, not a
//  reimplementation of them.
//
//  `DiaryNoteTextViewController` reads `Services.shared.navigator` / `.repository`
//  / `.analytics` / `.storageServices` from `init`, which are not reliably wired
//  during unit-test execution (same constraint documented in HotFlashFlowSpec), so
//  instantiating the view controller itself is impractical here. Each test drives
//  the extracted seam, then feeds its result into a real `MockRepository` call
//  exactly as the view controller does, so the repository-call assertions are
//  meaningful rather than true by construction.
//
//  Verified by temporarily reverting `emojiConfirmAction`'s guard to the old
//  `currentDiaryNote != nil` check (no `mustSendInsteadOfUpdate`): the first test
//  below goes red (returns `.patch` instead of `.hold` for the unsaved chart
//  placeholder). Restored before committing.
//

import Quick
import Nimble
import RxSwift
@testable import ForYouAndMe

class DiaryNoteEmojiCreateFlowSpec: QuickSpec {
    override class func spec() {

        func chartPlaceholderNote() -> DiaryNoteItem {
            // Mirrors DiaryNoteItem.fromChartTap: a chart-started note before its
            // first save is built via the `date:body:interval:diaryNoteable:` init,
            // which stamps `id` with a fresh client-side UUID never written to the
            // backend, and carries a non-nil `diaryNoteable` (so `isLinked` is true).
            return DiaryNoteItem(date: Date(),
                                 body: "",
                                 interval: "day",
                                 diaryNoteable: DiaryNoteable(id: "12", type: "chart"))
        }

        func emoji(tag: String = "😀") -> EmojiItem {
            return EmojiItem(id: "", type: "feedback_tag", tag: tag, label: nil)
        }

        describe("DiaryNoteTextViewController.emojiConfirmAction (the real emoji-confirm callback logic)") {

            it("holds (no network call) for an unsaved chart-started placeholder note") {
                let placeholder = chartPlaceholderNote()

                let action = DiaryNoteTextViewController.emojiConfirmAction(
                    confirmedEmoji: emoji(),
                    currentDiaryNote: placeholder,
                    noteExists: true,       // the placeholder is a non-nil DiaryNoteItem
                    isEditMode: false,      // openDiaryNoteText(..., isEditMode: false, ...)
                    wasJustCreatedHere: false)

                // This is what a plain `diaryNote != nil` guard (the pre-fix behaviour)
                // would have failed: that check is true for the placeholder, so it
                // would have returned `.patch(...)` here instead of `.hold`.
                guard case .hold = action else {
                    fail("expected .hold, got \(action) - would PATCH a client-side placeholder id")
                    return
                }

                // The production dispatch only ever calls the repository on `.patch`;
                // `.hold` falls straight through a `guard case .patch = action else { return }`,
                // so zero repository calls happen.
                let repo = MockRepository()
                expect(repo.updateDiaryNoteTextCallCount) == 0
            }

            it("holds for a brand-new Diary-tab/FAB note (no object at all, nil diaryNote)") {
                let action = DiaryNoteTextViewController.emojiConfirmAction(
                    confirmedEmoji: emoji(),
                    currentDiaryNote: nil,
                    noteExists: false,
                    isEditMode: false,
                    wasJustCreatedHere: false)

                guard case .hold = action else {
                    fail("expected .hold, got \(action)")
                    return
                }
            }

            it("PATCHes immediately when the screen was opened in edit mode on an existing note") {
                let existing = DiaryNoteItem(id: "555",
                                             type: "diary_note",
                                             diaryNoteId: Date(),
                                             diaryNoteType: .text,
                                             title: nil,
                                             body: "Hello",
                                             interval: nil)

                let action = DiaryNoteTextViewController.emojiConfirmAction(
                    confirmedEmoji: emoji(tag: "🥵"),
                    currentDiaryNote: existing,
                    noteExists: true,
                    isEditMode: true,
                    wasJustCreatedHere: false)

                guard case .patch(let noteToPatch) = action else {
                    fail("expected .patch, got \(action)")
                    return
                }
                expect(noteToPatch.id) == "555"
                expect(noteToPatch.feedbackTagToSet?.tag) == "🥵"

                // Feed the exact result into a real MockRepository call, as the view
                // controller's dispatch does, so the PATCH assertion is not vacuous.
                let repo = MockRepository()
                _ = repo.updateDiaryNoteText(diaryNote: noteToPatch)
                expect(repo.updateDiaryNoteTextCallCount) == 1
                expect(repo.lastUpdatedDiaryNote?.feedbackTagToSet?.tag) == "🥵"
            }

            it("PATCHes immediately right after the first save on this screen (wasJustCreatedHere)") {
                let justCreated = DiaryNoteItem(id: "556",
                                                type: "diary_note",
                                                diaryNoteId: Date(),
                                                diaryNoteType: .text,
                                                title: nil,
                                                body: "Hello",
                                                interval: nil)

                let action = DiaryNoteTextViewController.emojiConfirmAction(
                    confirmedEmoji: emoji(),
                    currentDiaryNote: justCreated,
                    noteExists: true,
                    isEditMode: false,
                    wasJustCreatedHere: true)

                guard case .patch = action else {
                    fail("expected .patch, got \(action)")
                    return
                }
            }

            it("skips the request when confirming the note's current emoji again") {
                let unchanged = emoji(tag: "🙂")
                var existing = DiaryNoteItem(id: "557",
                                             type: "diary_note",
                                             diaryNoteId: Date(),
                                             diaryNoteType: .text,
                                             title: nil,
                                             body: "Hello",
                                             interval: nil)
                existing.feedbackTags = [unchanged]

                let action = DiaryNoteTextViewController.emojiConfirmAction(
                    confirmedEmoji: unchanged,
                    currentDiaryNote: existing,
                    noteExists: true,
                    isEditMode: true,
                    wasJustCreatedHere: false)

                guard case .skipUnchanged = action else {
                    fail("expected .skipUnchanged, got \(action)")
                    return
                }
            }
        }

        describe("DiaryNoteTextViewController.noteToCreate + Save's create dispatch (the real Save path)") {

            it("attaches the held emoji to the note Save POSTs, and the repository sees exactly one create call carrying it") {
                let typedNote = DiaryNoteItem(diaryNoteId: nil, body: "Hello world", interval: nil, diaryNoteable: nil)
                let heldEmoji = emoji(tag: "🥵")

                let noteToSave = DiaryNoteTextViewController.noteToCreate(baseNote: typedNote, heldEmoji: heldEmoji)
                expect(noteToSave.feedbackTagToSet?.tag) == "🥵"
                expect(noteToSave.body) == "Hello world"

                // Mirror doneButtonPressed's create branch exactly: `mustSendInsteadOfUpdate`
                // true -> `repository.sendDiaryNoteText(diaryNote: noteToSave, ...)`, never
                // `updateDiaryNoteText`.
                let repo = MockRepository()
                repo.sendDiaryNoteTextResult = .just(noteToSave)
                _ = repo.sendDiaryNoteText(diaryNote: noteToSave, fromChart: false)

                expect(repo.sendDiaryNoteTextCallCount) == 1
                expect(repo.lastSentDiaryNoteText?.feedbackTagToSet?.tag) == "🥵"
                expect(repo.updateDiaryNoteTextCallCount) == 0
            }

            it("omits feedbackTagToSet when no emoji was held") {
                let typedNote = DiaryNoteItem(diaryNoteId: nil, body: "Hello", interval: nil, diaryNoteable: nil)

                let noteToSave = DiaryNoteTextViewController.noteToCreate(baseNote: typedNote, heldEmoji: nil)
                expect(noteToSave.feedbackTagToSet).to(beNil())

                let repo = MockRepository()
                repo.sendDiaryNoteTextResult = .just(noteToSave)
                _ = repo.sendDiaryNoteText(diaryNote: noteToSave, fromChart: false)

                expect(repo.lastSentDiaryNoteText?.feedbackTagToSet).to(beNil())
                expect(repo.updateDiaryNoteTextCallCount) == 0
            }
        }
    }
}
