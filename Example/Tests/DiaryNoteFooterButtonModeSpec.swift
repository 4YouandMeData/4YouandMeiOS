//
//  DiaryNoteFooterButtonModeSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3495: the "I've noticed" note footer button has three states driven by
//  the pure rule `DiaryNoteTextViewController.footerButtonMode(currentText:savedBody:noteExists:)`.
//
//  Contract under test (exact):
//    isSaved = noteExists && currentText == (savedBody ?? "")  -> .close
//    else trimmed(currentText).isEmpty                          -> .saveDisabled
//    else                                                       -> .saveEnabled
//
//  This spec drives the rule directly (no view controller instantiation needed).
//

import Quick
import Nimble
@testable import ForYouAndMe

class DiaryNoteFooterButtonModeSpec: QuickSpec {
    override class func spec() {
        describe("DiaryNoteTextViewController.footerButtonMode") {

            context("new note (noteExists == false)") {

                it("returns .saveDisabled with empty text") {
                    let result = DiaryNoteTextViewController.footerButtonMode(
                        currentText: "",
                        savedBody: nil,
                        noteExists: false)
                    expect(result).to(equal(.saveDisabled))
                }

                it("returns .saveDisabled with whitespace-only text") {
                    let result = DiaryNoteTextViewController.footerButtonMode(
                        currentText: "   ",
                        savedBody: nil,
                        noteExists: false)
                    expect(result).to(equal(.saveDisabled))
                }

                it("returns .saveEnabled with real text") {
                    let result = DiaryNoteTextViewController.footerButtonMode(
                        currentText: "hello",
                        savedBody: nil,
                        noteExists: false)
                    expect(result).to(equal(.saveEnabled))
                }
            }

            context("saved note (noteExists == true)") {

                it("returns .close when the text equals the saved body") {
                    let result = DiaryNoteTextViewController.footerButtonMode(
                        currentText: "hello",
                        savedBody: "hello",
                        noteExists: true)
                    expect(result).to(equal(.close))
                }

                it("returns .saveEnabled when the text has been edited") {
                    let result = DiaryNoteTextViewController.footerButtonMode(
                        currentText: "hello world",
                        savedBody: "hello",
                        noteExists: true)
                    expect(result).to(equal(.saveEnabled))
                }

                it("returns .saveDisabled when the text has been cleared") {
                    let result = DiaryNoteTextViewController.footerButtonMode(
                        currentText: "",
                        savedBody: "hello",
                        noteExists: true)
                    expect(result).to(equal(.saveDisabled))
                }

                it("returns .close for nil savedBody with empty current text (isSaved edge)") {
                    // isSaved = noteExists && ("" == (nil ?? "")) == true -> .close
                    let result = DiaryNoteTextViewController.footerButtonMode(
                        currentText: "",
                        savedBody: nil,
                        noteExists: true)
                    expect(result).to(equal(.close))
                }
            }
        }
    }
}
