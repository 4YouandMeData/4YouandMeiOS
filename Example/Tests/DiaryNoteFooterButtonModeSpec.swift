//
//  DiaryNoteFooterButtonModeSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3495: the "I've noticed" note footer button swaps its label + action
//  based on text presence. This spec drives the pure rule
//  `DiaryNoteTextViewController.footerIsSaveMode(pageState:trimmedText:)`
//  directly (no view controller instantiation needed).
//
//  Contract under test (exact): pageState == .edit && !trimmedText.isEmpty
//  The rule does NOT trim internally — trimming is the caller's job — so the
//  spec asserts the real contract and does not claim any internal trimming.
//

import Quick
import Nimble
@testable import ForYouAndMe

class DiaryNoteFooterButtonModeSpec: QuickSpec {
    override class func spec() {
        describe("DiaryNoteTextViewController.footerIsSaveMode") {

            it("returns true (Save mode) in .edit with non-empty text") {
                let result = DiaryNoteTextViewController.footerIsSaveMode(
                    pageState: .edit,
                    trimmedText: "Feeling great today")
                expect(result).to(beTrue())
            }

            it("returns false (Close mode) in .edit with empty text") {
                let result = DiaryNoteTextViewController.footerIsSaveMode(
                    pageState: .edit,
                    trimmedText: "")
                expect(result).to(beFalse())
            }

            it("returns false (Close mode) in .edit when the caller passes trimmed-empty text") {
                // The caller trims whitespace-only input to "" before calling the rule,
                // which yields Close mode.
                let result = DiaryNoteTextViewController.footerIsSaveMode(
                    pageState: .edit,
                    trimmedText: "")
                expect(result).to(beFalse())
            }

            it("does NOT trim internally: verbatim whitespace is treated as non-empty") {
                // Documents that the rule itself does not trim — trimming is the
                // caller's responsibility. Passing untrimmed whitespace verbatim
                // therefore returns true.
                let result = DiaryNoteTextViewController.footerIsSaveMode(
                    pageState: .edit,
                    trimmedText: "   ")
                expect(result).to(beTrue())
            }

            it("returns false (Close mode) in .read even with non-empty text") {
                let result = DiaryNoteTextViewController.footerIsSaveMode(
                    pageState: .read,
                    trimmedText: "An existing note")
                expect(result).to(beFalse())
            }

            it("returns false (Close mode) in .read with empty text") {
                let result = DiaryNoteTextViewController.footerIsSaveMode(
                    pageState: .read,
                    trimmedText: "")
                expect(result).to(beFalse())
            }
        }
    }
}
