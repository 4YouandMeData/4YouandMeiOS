//
//  FeedCardBackgroundBlendSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3584 / FUAM-3585: the dark-mode feed card fill is
//  `0.35 * feedBackground + 0.65 * cardBaseBackground`, blended in sRGB as
//  `(35*f + 65*c + 50) / 100` per channel in integer arithmetic (truncating division,
//  i.e. round-half-up). iOS and Android MUST produce the same color for the same
//  inputs, so the vectors below are the parity contract: the Android unit test
//  asserts the very same triples.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

private func hexString(_ color: UIColor) -> String {
    var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return String(format: "#%02X%02X%02X",
                  Int((red * 255.0).rounded()),
                  Int((green * 255.0).rounded()),
                  Int((blue * 255.0).rounded()))
}

class FeedCardBackgroundBlendSpec: QuickSpec {
    override class func spec() {
        describe("UIColor.blendedSRGB(with:percent:) — dark mode feed card fill") {

            // cardBase, feedBackground, expected @ 35% feed over card
            let vectors: [(String, Int, Int, String)] = [
                ("teal card over a near-black feed", 0x34CBD9, 0x101820, "#278C98"),
                ("white feed over a black card", 0x000000, 0xFFFFFF, "#595959"),
                ("black feed over a white card", 0xFFFFFF, 0x000000, "#A6A6A6"),
                ("identity when both colors match", 0x140F26, 0x140F26, "#140F26"),
                // Tie probe, card side: 65 * (10, 30, 50) / 100 is exactly 6.5 / 19.5 / 32.5.
                // Half-up must give 7 / 20 / 33; a half-to-even tie-break would give 6 / 20 / 32.
                ("rounds an exact .5 half-up (tie on the card channels)", 0x0A1E32, 0x000000, "#071421"),
                // Tie probe, feed side: 35 * (10, 30, 50) / 100 is exactly 3.5 / 10.5 / 17.5.
                ("rounds an exact .5 half-up (tie on the feed channels)", 0x000000, 0x0A1E32, "#040B12"),
                // Non-tie probe: exact results are 0.35 / 0.7 / 1.05.
                ("rounds sub-.5 down and super-.5 up", 0x000000, 0x010203, "#000101")
            ]

            vectors.forEach { (name, base, feed, expected) in
                it(name) {
                    let result = UIColor(hexRGB: base).blendedSRGB(with: UIColor(hexRGB: feed),
                                                                   percent: ColorPalette.darkFeedCardBlendPercent)
                    expect(hexString(result)).to(equal(expected))
                }
            }

            it("uses the 35% ratio agreed with Android") {
                expect(ColorPalette.darkFeedCardBlendPercent).to(equal(35))
            }

            it("always returns an opaque color") {
                let result = UIColor(hexRGB: 0x34CBD9).withAlphaComponent(0.3)
                    .blendedSRGB(with: UIColor(hexRGB: 0x101820), percent: 35)
                var alpha: CGFloat = 0.0
                result.getWhite(nil, alpha: &alpha)
                expect(alpha).to(equal(1.0))
            }
        }

        describe("ColorPalette.feedCardBackground") {

            let base = UIColor(hexRGB: 0x34CBD9)

            it("leaves the card untouched in light mode") {
                let resolved = ColorPalette.feedCardBackground(base)
                    .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                expect(hexString(resolved)).to(equal("#34CBD9"))
            }

            it("softens the card against the feed background in dark mode") {
                let trait = UITraitCollection(userInterfaceStyle: .dark)
                let feed = ColorPalette.color(withType: .secondaryBackgroungColor).resolvedColor(with: trait)
                let expected = base.blendedSRGB(with: feed, percent: ColorPalette.darkFeedCardBlendPercent)
                let resolved = ColorPalette.feedCardBackground(base).resolvedColor(with: trait)
                expect(hexString(resolved)).to(equal(hexString(expected)))
                expect(hexString(resolved)).toNot(equal("#34CBD9"))
            }
        }
    }
}
