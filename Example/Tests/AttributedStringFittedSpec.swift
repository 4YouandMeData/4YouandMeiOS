//
//  AttributedStringFittedSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3637: locks in the card-title auto-shrink helper.
//
//  The shipped fix relied on `adjustsFontSizeToFitWidth` + `numberOfLines = 2`, which no-ops on a
//  line-limited attributed label (UIKit truncates instead of shrinking). `NSAttributedString
//  .createFitted` replaces it by binary-searching the font scale so the title fits two lines.
//
//  The load-bearing trap this test guards: the fit MUST be measured on a `.byWordWrapping` copy.
//  `boundingRect` on a `.byTruncatingTail` string reports a single line, which would make every
//  scale "fit" and silently no-op the shrink — so this test measures the returned string's
//  word-wrapping height, not its (truncating) display height.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

class AttributedStringFittedSpec: QuickSpec {

    override class func spec() {
        describe("NSAttributedString.createFitted") {

            let availableWidth: CGFloat = 250.0
            let style: FontStyle = .header2
            let baseFont = FontPalette.fontStyleData(forStyle: style).font
            let lineSpacing = FontPalette.fontStyleData(forStyle: style).lineSpacing

            // Measures a word-wrapping copy of the result at the same width — mirrors the helper's
            // own measurement and is the ONLY measurement that reflects true wrapping.
            func wordWrappingHeight(of attributed: NSAttributedString, font: UIFont) -> CGFloat {
                let measured = NSMutableAttributedString(attributedString: attributed)
                measured.setLineBreakMode(.byWordWrapping)
                return measured.boundingRect(with: CGSize(width: availableWidth,
                                                          height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin], context: nil).height
            }

            func font(of attributed: NSAttributedString) -> UIFont {
                return attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont ?? baseFont
            }

            it("shrinks a long title so its word-wrapping height fits two lines") {
                // ~63 chars: wraps to three lines at full size in 250pt, fits two lines above the
                // 0.6 floor — the case the shipped adjustsFontSizeToFitWidth fix failed to shrink.
                let longTitle = "Long survey card title that must shrink to fit two lines nicely"
                let result = NSAttributedString.createFitted(withText: longTitle,
                                                             fontStyle: style,
                                                             color: .black,
                                                             availableWidth: availableWidth)
                let resultFont = font(of: result)
                // Font was actually shrunk below the base size.
                expect(resultFont.pointSize).to(beLessThan(baseFont.pointSize))
                // And the shrunk word-wrapping layout fits the two-line budget.
                let twoLineBudget = 2 * resultFont.lineHeight + lineSpacing
                expect(wordWrappingHeight(of: result, font: resultFont)).to(beLessThanOrEqualTo(twoLineBudget + 1.0))
            }

            it("leaves a short title at full size") {
                let shortTitle = "Short title"
                let result = NSAttributedString.createFitted(withText: shortTitle,
                                                             fontStyle: style,
                                                             color: .black,
                                                             availableWidth: availableWidth)
                expect(font(of: result).pointSize).to(equal(baseFont.pointSize))
            }
        }
    }
}
