//
//  EmojiPopupViewControllerSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3857: the sentinel ("no emoji") tile is inserted into `self.emojis` at index 0, but
//  `selectedIndexPath` used to be computed by searching the `emojis` initializer parameter
//  (no sentinel), which shadowed `self.emojis`. That put every restored selection one tile
//  too early against what the collection view actually renders.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

class EmojiPopupViewControllerSpec: QuickSpec {
    override class func spec() {
        describe("EmojiPopupViewController selection index vs. the sentinel offset") {

            let serverEmojis = [
                EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy"),
                EmojiItem(id: "2", type: "feedback_tag", tag: "😡", label: "angry"),
                EmojiItem(id: "3", type: "feedback_tag", tag: "😢", label: "sad")
            ]

            // `selectedIndexPath` is private; the closest reachable seam is the
            // UICollectionViewDataSource conformance, which is internal and testable, and
            // which surfaces the selection via EmojiCell's `selected`-driven background color.
            func isSelected(_ controller: EmojiPopupViewController, at indexPath: IndexPath) -> Bool {
                let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 400),
                                                       collectionViewLayout: UICollectionViewFlowLayout())
                collectionView.register(EmojiCell.self)
                collectionView.dataSource = controller
                collectionView.reloadData()
                collectionView.layoutIfNeeded()
                guard let cell = controller.collectionView(collectionView, cellForItemAt: indexPath) as? EmojiCell else {
                    fail("expected an EmojiCell")
                    return false
                }
                // ColorPalette.color(withType:) is a dynamic (trait-resolved) UIColor: two
                // separate calls produce two distinct provider closures that are never `==`
                // to each other, even when they resolve to the same color. Resolve both
                // against a fixed trait collection before comparing.
                let trait = UITraitCollection(userInterfaceStyle: .light)
                let actual = cell.contentView.backgroundColor?.resolvedColor(with: trait)
                let expected = ColorPalette.color(withType: .inactive).resolvedColor(with: trait)
                return actual == expected
            }

            it("selects the tile one position after the server index once the sentinel is inserted") {
                // Server index 1 ("angry"); the sentinel takes index 0, so the rendered
                // selection must land on index 2, not on the shadowed-parameter's index 1.
                let controller = EmojiPopupViewController(emojis: serverEmojis, selected: serverEmojis[1], onSave: { _ in })
                expect(isSelected(controller, at: IndexPath(item: 2, section: 0))).to(beTrue())
                expect(isSelected(controller, at: IndexPath(item: 1, section: 0))).to(beFalse())
            }

            it("does not resolve the first server emoji's selection onto the sentinel tile") {
                // Server index 0 ("happy") must render selected at index 1; the sentinel at
                // index 0 must stay unselected.
                let controller = EmojiPopupViewController(emojis: serverEmojis, selected: serverEmojis[0], onSave: { _ in })
                expect(isSelected(controller, at: IndexPath(item: 0, section: 0))).to(beFalse())
                expect(isSelected(controller, at: IndexPath(item: 1, section: 0))).to(beTrue())
            }
        }

        // FUAM-3857 (round 4, Jules): the sentinel is identified by POSITION (index 0, when
        // inserted), never by inspecting `label`. A real emoji configured with the label
        // "none" must render as itself, and must not be counted as a caption-less sentinel
        // for the row-height decision either.
        describe("EmojiPopupViewController identifies the sentinel by position, not by label") {

            it("does not treat a real item labelled 'none' as the sentinel") {
                let impostor = EmojiItem(id: "42", type: "feedback_tag", tag: "🙄", label: "none")
                let controller = EmojiPopupViewController(emojis: [impostor], selected: nil, onSave: { _ in })

                let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 400),
                                                       collectionViewLayout: UICollectionViewFlowLayout())
                collectionView.register(EmojiCell.self)
                collectionView.dataSource = controller
                collectionView.reloadData()

                // Index 0 is now the real sentinel this controller inserted (list wasn't
                // empty); the impostor, carrying the "none" label, sits at index 1 and must
                // render as itself.
                guard let cell = controller.collectionView(collectionView,
                                                            cellForItemAt: IndexPath(item: 1, section: 0)) as? EmojiCell else {
                    fail("expected an EmojiCell")
                    return
                }
                let glyphLabel = cell.contentView.subviews.flatMap { $0.subviews }.compactMap { $0 as? UILabel }
                    .first { $0.font.pointSize == 35 }
                expect(glyphLabel?.text).to(equal("🙄"))
                expect(glyphLabel?.isHidden).to(beFalse())
            }
        }
    }
}

// FUAM-3857: when no option in the list — including the sentinel — has any caption, the
// grid should not waste a blank caption row per line. The reduced height is FIXED (not
// derived from Dynamic-Type-scaled metrics at call time) because the cell's content
// (45pt icon, 4pt blank spacer, 8pt of stack spacing = 57pt required floor) doesn't shrink
// with the user's text size either — see EmojiPopUpViewController.compactRowHeight.
class EmojiPopupViewControllerRowHeightSpec: QuickSpec {
    override class func spec() {
        describe("EmojiPopupViewController row height (compact rows with no captions)") {

            let noCaptionEmojis = [
                EmojiItem(id: "1", type: "feedback_tag", tag: "😡", label: nil),
                EmojiItem(id: "2", type: "feedback_tag", tag: "😢", label: nil)
            ]
            let withCaptionEmojis = [
                EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy"),
                EmojiItem(id: "2", type: "feedback_tag", tag: "😢", label: nil)
            ]

            // Concrete expected numbers, not a re-derivation of production's own formula:
            // the previous version of this spec computed `reducedHeight` with the exact same
            // FontPalette expression production used, so it stayed green for every value that
            // expression could produce, including the Dynamic-Type-broken ones (round-3
            // review, finding 1).
            let fullHeight: CGFloat = 80
            let reducedHeight: CGFloat = 64
            let requiredFloor: CGFloat = 57 // 45pt icon + 4pt blank spacer + 2 x 4pt stack spacing

            afterEach {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
            }

            func itemHeight(_ controller: EmojiPopupViewController) -> CGFloat {
                let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 400),
                                                       collectionViewLayout: UICollectionViewFlowLayout())
                let size = controller.collectionView(collectionView,
                                                      layout: UICollectionViewFlowLayout(),
                                                      sizeForItemAt: IndexPath(item: 0, section: 0))
                return size.height
            }

            // Runs `body` with `UITraitCollection.current` overridden to `category` for the
            // duration of the call, then restores it. This is what makes
            // `UIFontMetrics.default.scaledFont(for:)` (used by FontPalette, and previously by
            // production's row-height formula) resolve against an accessibility text size
            // inside a unit test, without touching any global app/simulator setting.
            func withContentSizeCategory<T>(_ category: UIContentSizeCategory, _ body: () -> T) -> T {
                let original = UITraitCollection.current
                UITraitCollection.current = UITraitCollection(preferredContentSizeCategory: category)
                defer { UITraitCollection.current = original }
                return body()
            }

            it("reduces the item height when no item, including the sentinel, has a caption") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
                let controller = EmojiPopupViewController(emojis: noCaptionEmojis, selected: nil, onSave: { _ in })
                expect(itemHeight(controller)).to(equal(reducedHeight))
            }

            it("keeps the full height when at least one item has a caption") {
                let controller = EmojiPopupViewController(emojis: withCaptionEmojis, selected: nil, onSave: { _ in })
                expect(itemHeight(controller)).to(equal(fullHeight))
            }

            it("keeps the full height when EMOJI_NONE_LABEL is set, even though no server item has a caption") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Skip"])
                let controller = EmojiPopupViewController(emojis: noCaptionEmojis, selected: nil, onSave: { _ in })
                expect(itemHeight(controller)).to(equal(fullHeight))
            }

            it("does not shrink the reduced height as the user's Dynamic Type setting grows") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
                let controller = EmojiPopupViewController(emojis: noCaptionEmojis, selected: nil, onSave: { _ in })

                let defaultHeight = withContentSizeCategory(.large) { itemHeight(controller) }
                let accessibilityHeight = withContentSizeCategory(.accessibilityExtraExtraExtraLarge) { itemHeight(controller) }

                expect(defaultHeight).to(equal(reducedHeight))
                expect(accessibilityHeight).to(equal(reducedHeight))
                expect(accessibilityHeight).to(beGreaterThanOrEqualTo(requiredFloor))
            }

            it("still leaves the 45pt sentinel icon unclipped at the reduced height, default and accessibility text sizes") {
                for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
                    withContentSizeCategory(category) {
                        let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: reducedHeight))
                        let sentinel = EmojiItem(id: "", type: "", tag: "❌", label: "none")
                        cell.configure(with: sentinel, isNoneOption: true, selected: false)
                        cell.layoutIfNeeded()

                        let imageView = cell.contentView.subviews
                            .flatMap { $0.subviews }
                            .compactMap { $0 as? UIImageView }
                            .first
                        expect(imageView?.frame.height).to(beCloseTo(45, within: 0.5))
                        expect(imageView?.frame.maxY).to(beLessThanOrEqualTo(cell.contentView.bounds.height))
                        expect(imageView?.frame.minY).to(beGreaterThanOrEqualTo(0))
                    }
                }
            }
        }
    }
}
