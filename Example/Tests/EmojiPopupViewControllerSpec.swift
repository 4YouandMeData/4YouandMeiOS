//
//  EmojiPopupViewControllerSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3857: the "no emoji" tile is rendered at index 0 of the picker grid, ahead of every
//  study-configured emoji. Internally the grid is a `[.none] + emojis.map(.emoji)` list (a sum
//  type), never a synthetic `EmojiItem` inserted into the emoji array — so there is no value
//  anywhere that stands in for "no emoji" other than `nil` at the `onSelectionConfirmed`
//  boundary.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

class EmojiPopupViewControllerSpec: QuickSpec {
    override class func spec() {
        describe("EmojiPopupViewController selection index vs. the no-emoji tile offset") {

            let serverEmojis = [
                EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy"),
                EmojiItem(id: "2", type: "feedback_tag", tag: "😡", label: "angry"),
                EmojiItem(id: "3", type: "feedback_tag", tag: "😢", label: "sad")
            ]

            it("selects the tile one position after the server index once the no-emoji tile is inserted") {
                // Server index 1 ("angry"); the no-emoji tile takes index 0, so the rendered
                // selection must land on index 2.
                let controller = EmojiPopupViewController(emojis: serverEmojis,
                                                           selected: serverEmojis[1],
                                                           onSelectionConfirmed: { _ in })
                expect(isSelected(controller, at: IndexPath(item: 2, section: 0))).to(beTrue())
                expect(isSelected(controller, at: IndexPath(item: 1, section: 0))).to(beFalse())
            }

            it("does not resolve the first server emoji's selection onto the no-emoji tile") {
                // Server index 0 ("happy") must render selected at index 1; the no-emoji tile
                // at index 0 must stay unselected.
                let controller = EmojiPopupViewController(emojis: serverEmojis,
                                                           selected: serverEmojis[0],
                                                           onSelectionConfirmed: { _ in })
                expect(isSelected(controller, at: IndexPath(item: 0, section: 0))).to(beFalse())
                expect(isSelected(controller, at: IndexPath(item: 1, section: 0))).to(beTrue())
            }

            it("does not pre-select the no-emoji tile when nothing was ever recorded") {
                let controller = EmojiPopupViewController(emojis: serverEmojis, selected: nil, onSelectionConfirmed: { _ in })
                expect(isSelected(controller, at: IndexPath(item: 0, section: 0))).to(beFalse())
            }
        }

        // FUAM-3857 (round 4/5, Jules): identity is presence/absence of an `EmojiItem?`, never
        // a value inspected inside one. A real emoji configured with the label "none" must
        // render as itself, and must not be counted as a caption-less no-emoji tile either.
        describe("EmojiPopupViewController never keys identity off a value") {

            it("does not treat a real item labelled 'none' as the no-emoji option") {
                let impostor = EmojiItem(id: "42", type: "feedback_tag", tag: "🙄", label: "none")
                let controller = EmojiPopupViewController(emojis: [impostor], selected: nil, onSelectionConfirmed: { _ in })

                let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 400),
                                                       collectionViewLayout: UICollectionViewFlowLayout())
                collectionView.register(EmojiCell.self)
                collectionView.dataSource = controller
                collectionView.reloadData()

                // Index 0 is the real no-emoji tile this controller always includes; the
                // impostor, carrying the "none" label, sits at index 1 and must render as
                // itself.
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

            // `EmojiItem??` (whether the closure fired at all, wrapping whether it fired with
            // nil) trips a well-known Swift/Nimble ambiguity: `beNil()` on a double optional
            // flattens `.some(nil)` to "nil", so it can't tell "fired with nil" apart from
            // "never fired". A dedicated enum sidesteps it entirely.
            enum ConfirmationResult: Equatable { case notCalled; case confirmed(EmojiItem?) }

            it("saves nil (not a sentinel EmojiItem) when the no-emoji tile is confirmed") {
                var result: ConfirmationResult = .notCalled
                let controller = EmojiPopupViewController(emojis: [EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: nil)],
                                                           selected: nil,
                                                           onSelectionConfirmed: { result = .confirmed($0) })
                controller.loadViewIfNeeded()
                controller.collectionView(collectionView(for: controller), didSelectItemAt: IndexPath(item: 0, section: 0))
                saveTapped(controller)
                expect(result).to(equal(.confirmed(nil)))
            }

            it("saves the real item (not nil) when a study-configured emoji captioned 'None' is confirmed") {
                let impostor = EmojiItem(id: "42", type: "feedback_tag", tag: "🙂", label: "None")
                var result: ConfirmationResult = .notCalled
                let controller = EmojiPopupViewController(emojis: [impostor],
                                                           selected: nil,
                                                           onSelectionConfirmed: { result = .confirmed($0) })
                controller.loadViewIfNeeded()
                controller.collectionView(collectionView(for: controller), didSelectItemAt: IndexPath(item: 1, section: 0))
                saveTapped(controller)
                expect(result).to(equal(.confirmed(impostor)))
            }
        }

        // FUAM-3857 (round 5, Jules): the list length is entirely study-configured — 0, 1, or
        // ~100 real emoji are all valid, and the grid is meant to scroll. The no-emoji tile
        // must appear exactly once regardless of length.
        describe("EmojiPopupViewController options at variable list lengths") {

            func itemCount(_ controller: EmojiPopupViewController) -> Int {
                controller.collectionView(collectionView(for: controller), numberOfItemsInSection: 0)
            }

            func noneOptionCount(_ controller: EmojiPopupViewController, totalCount: Int) -> Int {
                let collectionView = collectionView(for: controller)
                var count = 0
                for index in 0..<totalCount {
                    guard let cell = controller.collectionView(collectionView,
                                                                cellForItemAt: IndexPath(item: index, section: 0)) as? EmojiCell
                    else { continue }
                    if isNoneOptionCell(cell) { count += 1 }
                }
                return count
            }

            it("offers exactly the no-emoji tile when the study configures zero real emoji") {
                // Deliberate: the old sentinel-insertion was gated on `!emojis.isEmpty`, so a
                // zero-item study produced an empty, unusable grid — no cells, Save
                // permanently disabled, only Cancel. "No emoji" is a first-class state
                // independent of how many real options exist, so it is always offered.
                let controller = EmojiPopupViewController(emojis: [], selected: nil, onSelectionConfirmed: { _ in })
                expect(itemCount(controller)).to(equal(1))
                expect(noneOptionCount(controller, totalCount: 1)).to(equal(1))
            }

            it("offers the no-emoji tile plus the one real emoji when the study configures one") {
                let one = [EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: nil)]
                let controller = EmojiPopupViewController(emojis: one, selected: nil, onSelectionConfirmed: { _ in })
                expect(itemCount(controller)).to(equal(2))
                expect(noneOptionCount(controller, totalCount: 2)).to(equal(1))
            }

            it("offers the no-emoji tile plus every real emoji when the study configures ~100") {
                let many = (0..<100).map { EmojiItem(id: "\($0)", type: "feedback_tag", tag: "🙂", label: "item\($0)") }
                let controller = EmojiPopupViewController(emojis: many, selected: nil, onSelectionConfirmed: { _ in })
                expect(itemCount(controller)).to(equal(101))
                expect(noneOptionCount(controller, totalCount: 101)).to(equal(1))
            }

            it("resolves the selection correctly near the END of a long list") {
                // This is where an off-by-one, or a wrong match key, shows up most clearly.
                let many = (0..<100).map { EmojiItem(id: "\($0)", type: "feedback_tag", tag: "🙂", label: "item\($0)") }
                let target = many[97]
                let controller = EmojiPopupViewController(emojis: many, selected: target, onSelectionConfirmed: { _ in })
                // Server index 97 -> rendered index 98 (the no-emoji tile takes index 0).
                expect(isSelected(controller, at: IndexPath(item: 98, section: 0))).to(beTrue())
                expect(isSelected(controller, at: IndexPath(item: 97, section: 0))).to(beFalse())
                expect(isSelected(controller, at: IndexPath(item: 99, section: 0))).to(beFalse())
            }
        }

        // FUAM-3857 (round 5, Jules): the card's height is a floor (>= 420), not a fixed
        // value, and the collection view is pinned between the title and the save button with
        // no height of its own — so nothing in this layout can be driven by item count. A long
        // list must scroll INSIDE the card, not push the save button off screen.
        describe("EmojiPopupViewController layout with a long list") {

            it("keeps the card at its 420pt floor and the save button on screen, regardless of item count") {
                let many = (0..<100).map { EmojiItem(id: "\($0)", type: "feedback_tag", tag: "🙂", label: "item\($0)") }
                let controller = EmojiPopupViewController(emojis: many, selected: nil, onSelectionConfirmed: { _ in })
                let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
                window.rootViewController = controller
                window.makeKeyAndVisible()
                controller.loadViewIfNeeded()
                controller.view.layoutIfNeeded()

                let cardView = controller.view.subviews.first
                expect(cardView).toNot(beNil())
                // The card is a MINIMUM (greaterThanOrEqual), and nothing in this hierarchy —
                // titleLabel, the fixed-height save button, or a UICollectionView (which has
                // no intrinsic content size) — can push it taller. It stays at its floor.
                expect(cardView?.frame.height).to(beCloseTo(420, within: 1))
                expect(cardView?.frame.maxY).to(beLessThanOrEqualTo(window.bounds.height))

                let collectionView = allSubviews(of: controller.view).first { $0 is UICollectionView } as? UICollectionView
                expect(collectionView).toNot(beNil())
                // 100 items don't fit in the available height: the grid scrolls internally
                // (contentSize taller than frame) instead of growing the card.
                expect(collectionView!.contentSize.height).to(beGreaterThan(collectionView!.frame.height))
            }
        }
    }
}

// FUAM-3857: when no option — including the no-emoji tile — has any caption, the grid should
// not waste a blank caption row per line. The reduced height is FIXED (not derived from
// Dynamic-Type-scaled metrics at call time) because the cell's content (45pt icon, 4pt blank
// spacer, 8pt of stack spacing = 57pt required floor) doesn't shrink with the user's text size
// either — see EmojiPopUpViewController.compactRowHeight.
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

            // Concrete expected numbers, not a re-derivation of production's own formula.
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
            // `UIFontMetrics.default.scaledFont(for:)` (used by FontPalette) resolve against
            // an accessibility text size inside a unit test, without touching any global
            // app/simulator setting.
            func withContentSizeCategory<T>(_ category: UIContentSizeCategory, _ body: () -> T) -> T {
                let original = UITraitCollection.current
                UITraitCollection.current = UITraitCollection(preferredContentSizeCategory: category)
                defer { UITraitCollection.current = original }
                return body()
            }

            it("reduces the item height when no option, including no-emoji, has a caption") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
                let controller = EmojiPopupViewController(emojis: noCaptionEmojis, selected: nil, onSelectionConfirmed: { _ in })
                expect(itemHeight(controller)).to(equal(reducedHeight))
            }

            it("keeps the full height when at least one item has a caption") {
                let controller = EmojiPopupViewController(emojis: withCaptionEmojis, selected: nil, onSelectionConfirmed: { _ in })
                expect(itemHeight(controller)).to(equal(fullHeight))
            }

            it("keeps the full height when EMOJI_NONE_LABEL is set, even though no server item has a caption") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Skip"])
                let controller = EmojiPopupViewController(emojis: noCaptionEmojis, selected: nil, onSelectionConfirmed: { _ in })
                expect(itemHeight(controller)).to(equal(fullHeight))
            }

            it("does not shrink the reduced height as the user's Dynamic Type setting grows") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
                let controller = EmojiPopupViewController(emojis: noCaptionEmojis, selected: nil, onSelectionConfirmed: { _ in })

                let defaultHeight = withContentSizeCategory(.large) { itemHeight(controller) }
                let accessibilityHeight = withContentSizeCategory(.accessibilityExtraExtraExtraLarge) { itemHeight(controller) }

                expect(defaultHeight).to(equal(reducedHeight))
                expect(accessibilityHeight).to(equal(reducedHeight))
                expect(accessibilityHeight).to(beGreaterThanOrEqualTo(requiredFloor))
            }

            it("still leaves the 45pt no-emoji icon unclipped at the reduced height, default and accessibility text sizes") {
                for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
                    withContentSizeCategory(category) {
                        let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: reducedHeight))
                        cell.configure(with: nil, selected: false)
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

// MARK: - Helpers

// `selectedIndexPath` is private; the closest reachable seam is the UICollectionViewDataSource
// conformance, which is internal and testable, and which surfaces the selection via EmojiCell's
// `selected`-driven background color.
private func collectionView(for controller: EmojiPopupViewController) -> UICollectionView {
    let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 400),
                                           collectionViewLayout: UICollectionViewFlowLayout())
    collectionView.register(EmojiCell.self)
    collectionView.dataSource = controller
    collectionView.reloadData()
    collectionView.layoutIfNeeded()
    return collectionView
}

private func isSelected(_ controller: EmojiPopupViewController, at indexPath: IndexPath) -> Bool {
    let cv = collectionView(for: controller)
    guard let cell = controller.collectionView(cv, cellForItemAt: indexPath) as? EmojiCell else {
        fail("expected an EmojiCell")
        return false
    }
    // ColorPalette.color(withType:) is a dynamic (trait-resolved) UIColor: two separate calls
    // produce two distinct provider closures that are never `==` to each other, even when they
    // resolve to the same color. Resolve both against a fixed trait collection before comparing.
    let trait = UITraitCollection(userInterfaceStyle: .light)
    let actual = cell.contentView.backgroundColor?.resolvedColor(with: trait)
    let expected = ColorPalette.color(withType: .inactive).resolvedColor(with: trait)
    return actual == expected
}

private func isNoneOptionCell(_ cell: EmojiCell) -> Bool {
    let imageView = cell.contentView.subviews.flatMap { $0.subviews }.compactMap { $0 as? UIImageView }.first
    return imageView?.isHidden == false
}

private func allSubviews(of view: UIView) -> [UIView] {
    view.subviews.flatMap { [$0] + allSubviews(of: $0) }
}

// `saveTapped` is a private @objc selector; invoke it the same way a real button tap would.
private func saveTapped(_ controller: EmojiPopupViewController) {
    controller.perform(NSSelectorFromString("saveTapped"))
}
