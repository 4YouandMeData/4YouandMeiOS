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
