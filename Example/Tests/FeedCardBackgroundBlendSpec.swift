//
//  FeedCardBackgroundBlendSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3584 / FUAM-3585: the dark-mode feed card fill is
//  `0.20 * feedBackground + 0.80 * cardBaseBackground`, blended in sRGB with each
//  channel rounded half-up on the 0...255 value. iOS and Android MUST produce the
//  same color for the same inputs, so the vectors below are the parity contract:
//  the Android unit test asserts the very same triples.
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
        describe("UIColor.blendedSRGB(with:alpha:) — dark mode feed card fill") {

            // cardBase, feedBackground, expected @ 20% feed over card
            let vectors: [(String, Int, Int, String)] = [
                ("teal card over a near-black feed", 0x34CBD9, 0x101820, "#2DA7B4"),
                ("white feed over a black card", 0x000000, 0xFFFFFF, "#333333"),
                ("black feed over a white card", 0xFFFFFF, 0x000000, "#CCCCCC"),
                ("identity when both colors match", 0x140F26, 0x140F26, "#140F26"),
                // Rounding probe: exact results are 0.2 / 0.4 / 0.6 — half-up keeps the 0.6 channel at 1.
                ("rounds each channel half-up", 0x000000, 0x010203, "#000001")
            ]

            vectors.forEach { (name, base, feed, expected) in
                it(name) {
                    let result = UIColor(hexRGB: base).blendedSRGB(with: UIColor(hexRGB: feed),
                                                                   alpha: ColorPalette.darkFeedCardBlendRatio)
                    expect(hexString(result)).to(equal(expected))
                }
            }

            it("uses the 20% ratio agreed with Android") {
                expect(ColorPalette.darkFeedCardBlendRatio).to(equal(0.20))
            }

            it("always returns an opaque color") {
                let result = UIColor(hexRGB: 0x34CBD9).withAlphaComponent(0.3)
                    .blendedSRGB(with: UIColor(hexRGB: 0x101820), alpha: 0.20)
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
                let expected = base.blendedSRGB(with: feed, alpha: ColorPalette.darkFeedCardBlendRatio)
                let resolved = ColorPalette.feedCardBackground(base).resolvedColor(with: trait)
                expect(hexString(resolved)).to(equal(hexString(expected)))
                expect(hexString(resolved)).toNot(equal("#34CBD9"))
            }
        }
    }
}
