//
//  DiaryNoteMustSendInsteadOfUpdateSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4255: a note started from a Compass chart tap is a local placeholder
//  (non-nil `DiaryNoteItem` with a client-side UUID, never written to the backend)
//  until the first Save on this screen. The emoji picker's hold-vs-send decision
//  used a bare `diaryNote != nil` check, which is true for that placeholder, so it
//  PATCHed a note id the backend has never seen -> 404.
//
//  `DiaryNoteTextViewController.mustSendInsteadOfUpdate(noteExists:isEditMode:wasJustCreatedHere:)`
//  is the single pure rule now shared by Save and by the emoji picker.
//
//  Contract under test (exact):
//    isFirstSaveInThisVC = !isEditMode && !wasJustCreatedHere
//    mustSendInsteadOfUpdate = !noteExists || isFirstSaveInThisVC
//

import Quick
import Nimble
@testable import ForYouAndMe

class DiaryNoteMustSendInsteadOfUpdateSpec: QuickSpec {
    override class func spec() {
        describe("DiaryNoteTextViewController.mustSendInsteadOfUpdate") {

            it("is true for an unsaved chart-started note (local placeholder, not yet persisted)") {
                // noteExists: true (the placeholder DiaryNoteItem), isEditMode: false (opened via
                // openDiaryNoteEditor(..., isEditMode: false, ...)), never saved on this screen yet.
                let result = DiaryNoteTextViewController.mustSendInsteadOfUpdate(
                    noteExists: true,
                    isEditMode: false,
                    wasJustCreatedHere: false)
                expect(result).to(beTrue())
            }

            it("is true for a brand-new note started from the Diary tab (no object at all)") {
                let result = DiaryNoteTextViewController.mustSendInsteadOfUpdate(
                    noteExists: false,
                    isEditMode: false,
                    wasJustCreatedHere: false)
                expect(result).to(beTrue())
            }

            it("is false right after the first save on this screen") {
                let result = DiaryNoteTextViewController.mustSendInsteadOfUpdate(
                    noteExists: true,
                    isEditMode: false,
                    wasJustCreatedHere: true)
                expect(result).to(beFalse())
            }

            it("is false when the screen is opened in edit mode on an existing note") {
                let result = DiaryNoteTextViewController.mustSendInsteadOfUpdate(
                    noteExists: true,
                    isEditMode: true,
                    wasJustCreatedHere: false)
                expect(result).to(beFalse())
            }
        }
    }
}
