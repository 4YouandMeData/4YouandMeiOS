//
//  MenstrualPeriodEntryCellSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2934: verifies the menstrual period detail row renders the bleeding
//  date and toggles the optional note preview.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

class MenstrualPeriodEntryCellSpec: QuickSpec {
    override class func spec() {
        describe("MenstrualPeriodEntryCell.display(date:note:)") {

            it("shows a formatted date and the note preview when provided") {
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                let date = Date(timeIntervalSince1970: 1_750_000_000)
                cell.display(date: date, note: "Cramps in the afternoon")

                let dateLabel = findLabel(in: cell, matching: { $0.text?.contains("2025") == true || $0.text?.contains("2026") == true || $0.text?.contains("Jun") == true })
                let noteLabel = findLabel(in: cell, matching: { $0.text == "Cramps in the afternoon" })

                expect(dateLabel).toNot(beNil(), description: "date label not found")
                expect(noteLabel).toNot(beNil(), description: "note label not populated")
                expect(noteLabel?.isHidden).to(beFalse())
            }

            it("hides the note preview when the note is nil") {
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                cell.display(date: Date(), note: nil)

                let allLabels = collectLabels(in: cell)
                let noteLabel = allLabels.first(where: { $0.isHidden })
                expect(noteLabel).toNot(beNil())
                expect(noteLabel?.text).to(beNil())
            }

            it("hides the note preview when the note is an empty string") {
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                cell.display(date: Date(), note: "")

                let allLabels = collectLabels(in: cell)
                let noteLabel = allLabels.first(where: { $0.isHidden })
                expect(noteLabel).toNot(beNil())
            }
        }

        // FUAM-2934 / FUAM-2939: emoji column reflects the entry's last
        // feedback tag — populated by the detail screen's per-entry refetch
        // that works around the BE's missing nested-include.
        describe("MenstrualPeriodEntryCell.display(entry:) emoji column") {

            func makeEntry(feedbackTags: [EmojiItem]?) -> DiaryNoteItem {
                var entry = DiaryNoteItem(
                    id: "1",
                    type: "diary_note",
                    diaryNoteId: Date(timeIntervalSince1970: 1_750_000_000),
                    diaryNoteType: .menstrualPeriod,
                    title: nil,
                    body: nil,
                    interval: nil
                )
                entry.feedbackTags = feedbackTags
                return entry
            }

            it("shows the last feedback tag emoji when the entry carries one") {
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                let tag = EmojiItem(id: "286", type: "feedback_tag", tag: "🥵", label: nil)
                cell.display(entry: makeEntry(feedbackTags: [tag]))

                let emojiLabel = findLabel(in: cell, matching: { $0.text == "🥵" })
                expect(emojiLabel).toNot(beNil(), description: "emoji label not populated")
                expect(emojiLabel?.isHidden).to(beFalse())
            }

            it("prefers the LAST emoji when multiple feedback tags are present") {
                // Mirrors the post-PATCH state where the prior tag is retained
                // by the BE alongside the newly-picked one — the cell should
                // surface the most recent selection.
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                let prior = EmojiItem(id: "283", type: "feedback_tag", tag: "🤢", label: nil)
                let latest = EmojiItem(id: "286", type: "feedback_tag", tag: "🥵", label: nil)
                cell.display(entry: makeEntry(feedbackTags: [prior, latest]))

                let emojiLabel = findLabel(in: cell, matching: { $0.text == "🥵" })
                expect(emojiLabel).toNot(beNil())
                let priorLabel = findLabel(in: cell, matching: { $0.text == "🤢" })
                expect(priorLabel).to(beNil(), description: "only the latest tag should render")
            }

            // The emoji label has a unique 22pt system font; the date/note
            // labels use the body / footnote dynamic-type styles. Locating
            // it by font keeps the assertion robust against text changes.
            func emojiLabel(in cell: UIView) -> UILabel? {
                let target = UIFont.systemFont(ofSize: 22)
                return collectLabels(in: cell).first {
                    $0.font.pointSize == target.pointSize && $0.font.fontName == target.fontName
                }
            }

            it("hides the emoji label when feedbackTags is nil") {
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                cell.display(entry: makeEntry(feedbackTags: nil))

                let label = emojiLabel(in: cell)
                expect(label).toNot(beNil(), description: "emoji label not in hierarchy")
                expect(label?.isHidden).to(beTrue())
                expect(label?.text).to(beNil())
            }

            it("hides the emoji label when feedbackTags is empty") {
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                cell.display(entry: makeEntry(feedbackTags: []))

                let label = emojiLabel(in: cell)
                expect(label?.isHidden).to(beTrue())
                expect(label?.text).to(beNil())
            }

            it("hides the emoji label when the last tag is the 'none' sentinel") {
                let cell = MenstrualPeriodEntryCell(style: .default, reuseIdentifier: nil)
                let none = EmojiItem(id: "", type: "", tag: "❌", label: "none")
                cell.display(entry: makeEntry(feedbackTags: [none]))

                let label = emojiLabel(in: cell)
                expect(label?.isHidden).to(beTrue())
                expect(label?.text).to(beNil())
            }
        }
    }
}

// MARK: - Helpers

private func collectLabels(in view: UIView) -> [UILabel] {
    var result: [UILabel] = []
    if let label = view as? UILabel { result.append(label) }
    for subview in view.subviews {
        result.append(contentsOf: collectLabels(in: subview))
    }
    return result
}

private func findLabel(in view: UIView, matching predicate: (UILabel) -> Bool) -> UILabel? {
    return collectLabels(in: view).first(where: predicate)
}
