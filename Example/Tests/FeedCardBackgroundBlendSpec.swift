//
//  FeedCardBackgroundBlendSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3584 / FUAM-3585: the dark-mode feed card fill is
//  `0.35 * secondaryColor + 0.65 * cardBaseBackground`, blended in sRGB as
//  `(35*s + 65*c + 50) / 100` per channel in integer arithmetic (truncating division,
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

            // cardBase, secondaryColor, expected @ 35% secondary over card.
            // The 12 vectors are the cross-platform parity contract (Android asserts the same triples).
            let vectors: [(String, Int, Int, String)] = [
                ("teal card over a near-black secondary", 0x34CBD9, 0x101820, "#278C98"),
                ("white secondary over a black card", 0x000000, 0xFFFFFF, "#595959"),
                ("black secondary over a white card", 0xFFFFFF, 0x000000, "#A6A6A6"),
                ("identity when both colors match", 0x140F26, 0x140F26, "#140F26"),
                ("white secondary over a teal card", 0x34CBD9, 0xFFFFFF, "#7BDDE6"),
                ("dark secondary (0x2C2C2E) over a teal card", 0x34CBD9, 0x2C2C2E, "#31939D"),
                ("mid gray secondary over a mid gray card", 0x808080, 0x404040, "#6A6A6A"),
                ("full-blue secondary over a full-red card", 0xFF0000, 0x0000FF, "#A60059"),
                // Tie probe, card side: 65 * (10, 30, 50) / 100 is exactly 6.5 / 19.5 / 32.5.
                // Half-up must give 7 / 20 / 33; a half-to-even tie-break would give 6 / 20 / 32.
                ("rounds an exact .5 half-up (tie on the card channels)", 0x0A1E32, 0x000000, "#071421"),
                // Tie probe, secondary side: 35 * (10, 30, 50) / 100 is exactly 3.5 / 10.5 / 17.5.
                ("rounds an exact .5 half-up (tie on the secondary channels)", 0x000000, 0x0A1E32, "#040B12"),
                // Tie probe, both sides: card 65*30=19.5 and secondary 35*10=3.5 sum to a .5 result.
                ("rounds an exact .5 half-up (tie on both sides)", 0x1E1E1E, 0x0A0A0A, "#171717"),
                // Non-tie probe: exact results are 0.35 / 0.7 / 1.05.
                ("rounds sub-.5 down and super-.5 up", 0x000000, 0x010203, "#000101")
            ]

            vectors.forEach { (name, base, secondary, expected) in
                it(name) {
                    let result = UIColor(hexRGB: base).blendedSRGB(with: UIColor(hexRGB: secondary),
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

            it("blends the card with the secondary color in dark mode") {
                let trait = UITraitCollection(userInterfaceStyle: .dark)
                let secondary = ColorPalette.color(withType: .secondary).resolvedColor(with: trait)
                let expected = base.blendedSRGB(with: secondary, percent: ColorPalette.darkFeedCardBlendPercent)
                let resolved = ColorPalette.feedCardBackground(base).resolvedColor(with: trait)
                expect(hexString(resolved)).to(equal(hexString(expected)))
                expect(hexString(resolved)).toNot(equal("#34CBD9"))
            }
        }

        describe("ColorPalette.feedCardIconTint") {

            it("is clear in light mode (icon untouched)") {
                let resolved = ColorPalette.feedCardIconTint
                    .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
                var alpha: CGFloat = 1.0
                resolved.getWhite(nil, alpha: &alpha)
                expect(alpha).to(equal(0.0))
            }

            it("is the secondary color at 35% in dark mode") {
                let trait = UITraitCollection(userInterfaceStyle: .dark)
                let secondary = ColorPalette.color(withType: .secondary).resolvedColor(with: trait)
                let resolved = ColorPalette.feedCardIconTint.resolvedColor(with: trait)
                var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
                secondary.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
                var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
                resolved.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
                expect(rr).to(beCloseTo(sr, within: 0.001))
                expect(rg).to(beCloseTo(sg, within: 0.001))
                expect(rb).to(beCloseTo(sb, within: 0.001))
                expect(ra).to(beCloseTo(0.35, within: 0.001))
            }
        }
    }
}
