//
//  DiaryNoteItemHotFlashCellSpec.swift
//  ForYouAndMe_Tests
//
//  Cell rendering: emoji visibility + tap callback.
//

import Quick
import Nimble
import Foundation
@testable import ForYouAndMe

class DiaryNoteItemHotFlashCellSpec: QuickSpec {
    override func spec() {

        describe("DiaryNoteItemHotFlashTableViewCell") {

            var cell: DiaryNoteItemHotFlashTableViewCell!

            beforeEach {
                cell = DiaryNoteItemHotFlashTableViewCell(style: .default, reuseIdentifier: nil)
            }

            it("hides the emoji label when feedbackTags is nil") {
                let note = DiaryNoteItem(id: "n1", type: "diary_note", diaryNoteId: Date(),
                                         diaryNoteType: .hotFlash, title: nil, body: nil, interval: nil)

                cell.display(data: note, onTap: { })

                let emojiLabel = cell.subviews(ofType: UILabel.self).first(where: { $0.font.pointSize == 12 })
                expect(emojiLabel?.isHidden) == true
            }

            it("shows the last feedback emoji tag when present") {
                var note = DiaryNoteItem(id: "n2", type: "diary_note", diaryNoteId: Date(),
                                         diaryNoteType: .hotFlash, title: nil, body: nil, interval: nil)
                note.feedbackTags = [
                    EmojiItem(id: "e1", type: "emoji_item", tag: "🥵", label: "on fire")
                ]

                cell.display(data: note, onTap: { })

                let emojiLabel = cell.subviews(ofType: UILabel.self).first(where: { $0.font.pointSize == 12 })
                expect(emojiLabel?.isHidden) == false
                expect(emojiLabel?.text) == "🥵"
            }

            it("invokes onTap when cellTapped is fired") {
                let note = DiaryNoteItem(id: "n3", type: "diary_note", diaryNoteId: Date(),
                                         diaryNoteType: .hotFlash, title: nil, body: nil, interval: nil)
                var tapped = false
                cell.display(data: note, onTap: { tapped = true })

                cell.perform(NSSelectorFromString("cellTapped"))

                expect(tapped) == true
            }
        }
    }
}

// MARK: - Test helpers

private extension UIView {
    func subviews<T>(ofType type: T.Type) -> [T] {
        var matches: [T] = []
        if let self = self as? T { matches.append(self) }
        for child in subviews {
            matches.append(contentsOf: child.subviews(ofType: type))
        }
        return matches
    }
}
