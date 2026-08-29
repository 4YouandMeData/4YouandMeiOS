//
//  EmojiCellSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3857: the "none / no emoji" option in the emoji picker renders the
//  designer's `emoji_none` icon instead of the emoji glyph. It is modelled as
//  the ABSENCE of an `EmojiItem` (`nil`), never as a synthetic member of the
//  emoji list — there is no sentinel value anywhere in this cell.
//

import Quick
import Nimble
import UIKit
@testable import ForYouAndMe

class EmojiCellSpec: QuickSpec {
    override class func spec() {
        describe("EmojiCell.configure(with:selected:)") {

            let normalItem = EmojiItem(id: "286", type: "feedback_tag", tag: "🥵", label: nil)

            // These examples read the no-emoji caption from StringsProvider, which is global
            // state other specs also write. Reset it so this block cannot depend on suite
            // ordering.
            beforeEach {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
            }

            func makeCell() -> EmojiCell {
                EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
            }

            it("shows the emoji_none image and hides the emoji glyph when item is nil") {
                let cell = makeCell()
                cell.configure(with: nil, selected: false)

                let imageView = findImageView(in: cell)
                expect(imageView).toNot(beNil(), description: "none image view not found")
                expect(imageView?.isHidden).to(beFalse())
                // Deliberately not compared against ImagePalette.image(withName: .emojiNone):
                // that is the same call the cell makes, so the assertion would hold for any
                // artwork. Check the asset's own identity instead — the designer's export is
                // a 45x45pt square at @1x/@2x/@3x.
                expect(imageView?.image).toNot(beNil(), description: "emoji_none asset did not resolve")
                expect(imageView?.image?.size).to(equal(CGSize(width: 45, height: 45)))

                let emojiLabel = findLabel(in: cell, matching: { $0.font.pointSize == EmojiCell.glyphSlotHeight })
                expect(emojiLabel?.isHidden).to(beTrue())
                expect(emojiLabel?.text).to(beNil())
            }

            // FUAM-3857: the no-emoji icon's baked-in grey (#D9D9D9) sits almost on top of the
            // selected-cell background (ColorPalette .inactive, #DFDFDF by default in light
            // mode) — selecting the tile made the icon all but disappear, mirroring an Android
            // bug fixed the same way there. Tint white ONLY while selected; keep the designer's
            // original colour otherwise (the asset stays outside `Templates/` on purpose, so it
            // must never be blanket-tinted).
            it("keeps the no-emoji icon in its original colour when not selected") {
                let cell = makeCell()
                cell.configure(with: nil, selected: false)

                let imageView = findImageView(in: cell)
                expect(imageView?.image?.renderingMode).to(equal(.alwaysOriginal))
            }

            it("tints the no-emoji icon white when its tile is selected") {
                let cell = makeCell()
                cell.configure(with: nil, selected: true)

                let imageView = findImageView(in: cell)
                expect(imageView?.image?.renderingMode).to(equal(.alwaysTemplate))
                expect(imageView?.tintColor).to(equal(.white))
            }

            // Regression guard for the constraint conflict this cell is prone to: the stack is
            // pinned to all four edges of a fixed 80pt cell and distributes .fill, so the
            // blank-caption "no emoji" state must still leave something stretchable. With only
            // the 45pt icon and the 4pt blank space at required priority, Auto Layout breaks a
            // constraint and the icon is mispositioned or stretched.
            it("lays the no-emoji icon out at its intrinsic size with no caption configured") {
                let cell = makeCell()
                cell.configure(with: nil, selected: false)
                cell.layoutIfNeeded()

                let imageView = findImageView(in: cell)
                expect(imageView?.frame.height).to(beCloseTo(45, within: 0.5))
                expect(imageView?.frame.width).to(beCloseTo(45, within: 0.5))
                expect(imageView?.frame.maxY).to(beLessThanOrEqualTo(cell.contentView.bounds.height))
                expect(imageView?.frame.minY).to(beGreaterThanOrEqualTo(0))
            }

            it("shows the tag glyph and hides the none image for a normal item") {
                let cell = makeCell()
                cell.configure(with: normalItem, selected: false)

                let emojiLabel = findLabel(in: cell, matching: { $0.font.pointSize == EmojiCell.glyphSlotHeight })
                expect(emojiLabel?.isHidden).to(beFalse())
                expect(emojiLabel?.text).to(equal("🥵"))

                let imageView = findImageView(in: cell)
                expect(imageView?.isHidden).to(beTrue())
            }

            it("shows a blank caption for no-emoji by default, and item.label for a normal item") {
                let noneCell = makeCell()
                noneCell.configure(with: nil, selected: false)
                expect(findTitleLabel(in: noneCell)?.text).to(equal(""))
                // Not hidden: an empty label is the stack's only stretchable arranged
                // subview in this state (see EmojiCell.configure). Blank text renders nothing.
                expect(findTitleLabel(in: noneCell)?.isHidden).to(beFalse())

                let normalCell = makeCell()
                let happyItem = EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy")
                normalCell.configure(with: happyItem, selected: false)
                expect(findLabel(in: normalCell, matching: { $0.text == "happy" })).toNot(beNil())
            }

            it("leaves no stale icon when reused from no-emoji into a normal item") {
                let cell = makeCell()
                cell.configure(with: nil, selected: false)
                cell.configure(with: normalItem, selected: false)

                expect(findImageView(in: cell)?.isHidden).to(beTrue())
                let emojiLabel = findLabel(in: cell, matching: { $0.font.pointSize == EmojiCell.glyphSlotHeight })
                expect(emojiLabel?.isHidden).to(beFalse())
                expect(emojiLabel?.text).to(equal("🥵"))
            }

            it("leaves no stale glyph when reused from a normal item into no-emoji") {
                let cell = makeCell()
                cell.configure(with: normalItem, selected: false)
                cell.configure(with: nil, selected: false)

                let emojiLabel = findLabel(in: cell, matching: { $0.font.pointSize == EmojiCell.glyphSlotHeight })
                expect(emojiLabel?.isHidden).to(beTrue())
                expect(emojiLabel?.text).to(beNil())
                expect(findImageView(in: cell)?.isHidden).to(beFalse())
            }

            it("clears state on prepareForReuse") {
                let cell = makeCell()
                cell.configure(with: nil, selected: false)
                cell.prepareForReuse()

                expect(findImageView(in: cell)?.isHidden).to(beTrue())
                let emojiLabel = findLabel(in: cell, matching: { $0.font.pointSize == EmojiCell.glyphSlotHeight })
                expect(emojiLabel?.text).to(beNil())
                expect(findImageView(in: cell)?.isAccessibilityElement).to(beFalse())
                expect(findImageView(in: cell)?.accessibilityLabel).to(beNil())
            }

            // Replacing the glyph with a UIImageView removes the no-emoji option's only
            // accessible content once the caption is blank (a UIImageView is not an
            // accessibility element by default, and UICollectionViewCell does not aggregate
            // its children), so VoiceOver would announce nothing at all.
            it("exposes the no-emoji option to VoiceOver even with a blank caption") {
                let cell = makeCell()
                cell.configure(with: nil, selected: false)

                let imageView = findImageView(in: cell)
                expect(imageView?.isAccessibilityElement).to(beTrue())
                expect(imageView?.accessibilityLabel).to(equal("none"))
            }

            it("announces the configured caption instead, when a study sets one") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Remove"])
                defer { StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:]) }

                let cell = makeCell()
                cell.configure(with: nil, selected: false)
                expect(findImageView(in: cell)?.accessibilityLabel).to(equal("Remove"))
            }

            it("does not mark a normal item's image view as an accessibility element") {
                let cell = makeCell()
                cell.configure(with: normalItem, selected: false)

                expect(findImageView(in: cell)?.isAccessibilityElement).to(beFalse())
                expect(findImageView(in: cell)?.accessibilityLabel).to(beNil())
            }

            // FUAM-3857 (round 5, Jules): identity is presence/absence of an `EmojiItem?`, not
            // a value inspected inside one. A real study emoji that happens to carry the
            // literal label "none" (or the tag "❌") must still render as itself — its glyph,
            // its own label as caption.
            it("renders a real item as itself, not as no-emoji, even if its label is literally 'none'") {
                let impostor = EmojiItem(id: "99", type: "feedback_tag", tag: "🙄", label: "none")
                let cell = makeCell()
                cell.configure(with: impostor, selected: false)

                let emojiLabel = findLabel(in: cell, matching: { $0.font.pointSize == EmojiCell.glyphSlotHeight })
                expect(emojiLabel?.isHidden).to(beFalse())
                expect(emojiLabel?.text).to(equal("🙄"))
                expect(findImageView(in: cell)?.isHidden).to(beTrue())
                expect(findTitleLabel(in: cell)?.text).to(equal("none"),
                                                           description: "the item's own label, verbatim — not EMOJI_NONE_LABEL")
            }

            it("renders a study-configured ❌ as a glyph, never as the no-emoji icon") {
                let realCross = EmojiItem(id: "12", type: "feedback_tag", tag: "❌", label: "Not today")
                let cell = makeCell()
                cell.configure(with: realCross, selected: false)

                let emojiLabel = findLabel(in: cell, matching: { $0.font.pointSize == EmojiCell.glyphSlotHeight })
                expect(emojiLabel?.isHidden).to(beFalse())
                expect(emojiLabel?.text).to(equal("❌"))
                expect(findImageView(in: cell)?.isHidden).to(beTrue())
                expect(findTitleLabel(in: cell)?.text).to(equal("Not today"))
            }
        }

        // FUAM-3857: the no-emoji option's caption is study-configurable via the
        // EMOJI_NONE_LABEL strings key, decoupled from any internal "label == none" literal.
        describe("EmojiCell no-emoji caption (EMOJI_NONE_LABEL study string)") {

            afterEach {
                // Restore the ambient default state (no study strings configured) so this
                // spec doesn't leak global StringsProvider state into other specs.
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
            }

            it("renders a blank caption (not 'none', not the raw key) when the key is absent from the study config") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])

                let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
                cell.configure(with: nil, selected: false)

                let title = findTitleLabel(in: cell)
                expect(title?.text).to(equal(""))
                expect(title?.isHidden).to(beFalse(), description: "kept visible but blank; it absorbs the stack's slack")
                expect(findLabel(in: cell, matching: { $0.text == "none" })).to(beNil())
                expect(findLabel(in: cell, matching: { $0.text == "EMOJI_NONE_LABEL" })).to(beNil())
            }

            it("renders the configured value when the key is present") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Skip"])

                let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
                cell.configure(with: nil, selected: false)

                let title = findTitleLabel(in: cell)
                expect(title?.text).to(equal("Skip"))
                expect(title?.isHidden).to(beFalse())
                expect(findLabel(in: cell, matching: { $0.text == "none" })).to(beNil())
            }

            it("renders a blank caption (not 'none', not the raw key) when the key is explicitly empty") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: ""])

                let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
                cell.configure(with: nil, selected: false)

                let title = findTitleLabel(in: cell)
                expect(title?.text).to(equal(""))
                expect(title?.isHidden).to(beFalse(), description: "kept visible but blank; it absorbs the stack's slack")
                expect(findLabel(in: cell, matching: { $0.text == "none" })).to(beNil())
                expect(findLabel(in: cell, matching: { $0.text == "EMOJI_NONE_LABEL" })).to(beNil())
            }

            it("treats a whitespace-only EMOJI_NONE_LABEL as no caption too") {
                // Matches Android's isNotBlank() semantics and GlobalConfig+Mappable's honest
                // (nil, not " ") mapping for a label-less catalog item.
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "   "])

                let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
                cell.configure(with: nil, selected: false)

                expect(findTitleLabel(in: cell)?.text).to(equal(""))
            }

            it("leaves a normal item's caption unaffected by the EMOJI_NONE_LABEL key") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Skip"])

                let normalItem = EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy")
                let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
                cell.configure(with: normalItem, selected: false)

                expect(findLabel(in: cell, matching: { $0.text == "happy" })).toNot(beNil())
                expect(findLabel(in: cell, matching: { $0.text == "Skip" })).to(beNil())
            }

            // Regression guard. `item?.label ?? <none caption>` flattens to String?, so the
            // fallback fires for an UNLABELLED REAL emoji as well as for the no-emoji option,
            // printing the no-emoji caption under every glyph in a label-less study list. The
            // spec above cannot catch it because its item has a label; this one has none.
            it("leaves an unlabelled real emoji with no caption even when EMOJI_NONE_LABEL is set") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Skip"])

                let unlabelled = EmojiItem(id: "286", type: "feedback_tag", tag: "😡", label: nil)
                let cell = EmojiCell(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
                cell.configure(with: unlabelled, selected: false)

                expect(EmojiCell.displayedCaption(for: unlabelled)).to(equal(""))
                expect(findTitleLabel(in: cell)?.text).to(equal(""))
                expect(findLabel(in: cell, matching: { $0.text == "Skip" })).to(beNil())
            }

            it("still gives the no-emoji option its configured caption in the same study") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [.emojiNoneLabel: "Skip"])

                // Same configuration as above: the caption belongs to the no-emoji option
                // only, so nil must resolve to it while a real unlabelled item resolves to "".
                expect(EmojiCell.displayedCaption(for: nil)).to(equal("Skip"))
            }
        }

        // FUAM-3857 round 8 (Jules): a long caption like "pasta pastafarian" shrinks to fit
        // before it ellipsises, at least 2pt below the base size (mirrored on Android as 2sp).
        // `adjustsFontSizeToFitWidth` + `minimumScaleFactor` do the shrinking natively; below the
        // floor, the pre-existing `.byTruncatingTail` takes back over.
        //
        // These specs predict UILabel's own single-line layout math (`NSString.size(withAttributes:)`,
        // the same measurement `adjustsFontSizeToFitWidth` uses internally) rather than asserting
        // on rendered pixels, so they stay deterministic across whatever Dynamic Type / content
        // size category the test host happens to be running under — everything is measured
        // against the label's OWN live base font, never a hardcoded point size.
        describe("EmojiCell caption shrink-to-fit before ellipsis") {

            func makeCell(width: CGFloat = 80) -> EmojiCell {
                EmojiCell(frame: CGRect(x: 0, y: 0, width: width, height: 80))
            }

            func naturalWidth(_ text: String, font: UIFont) -> CGFloat {
                (text as NSString).size(withAttributes: [.font: font]).width
            }

            it("configures adjustsFontSizeToFitWidth with the 11pt floor coordinated with Android") {
                let cell = makeCell()
                let item = EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy")
                cell.configure(with: item, selected: false)

                let title = findTitleLabel(in: cell)
                expect(title?.adjustsFontSizeToFitWidth).to(beTrue())
                expect(title?.numberOfLines).to(equal(1))
                expect(title?.lineBreakMode).to(equal(.byTruncatingTail))

                let basePointSize = title!.font.pointSize
                let expectedFloor = min(EmojiCell.captionFloorPointSize, basePointSize - EmojiCell.captionMinShrinkPoints)
                expect(title?.minimumScaleFactor).to(beCloseTo(expectedFloor / basePointSize, within: 0.001))
            }

            // At the default content size category, `.header3`'s base is 13pt (see
            // FontPalette.FontStyle.defaultData) and the coordinated floor is 11pt — exactly the
            // 2pt minimum, with zero margin to spare (Android's 14sp base gives it 3sp). This
            // pins that fact down so a future `.header3` change that erodes the margin further
            // trips the `assert` in EmojiCell.setupUI instead of silently shrinking less.
            it("has exactly 2pt of margin at the default content size category (13pt base, 11pt floor)") {
                let original = UITraitCollection.current
                UITraitCollection.current = UITraitCollection(preferredContentSizeCategory: .large)
                defer { UITraitCollection.current = original }

                let cell = makeCell()
                let item = EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy")
                cell.configure(with: item, selected: false)

                expect(findTitleLabel(in: cell)?.font.pointSize).to(beCloseTo(13, within: 0.01))
            }

            it("renders a short caption at the base size, since it already fits unshrunk") {
                let cell = makeCell()
                let item = EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: "happy")
                cell.configure(with: item, selected: false)
                cell.layoutIfNeeded()

                let title = findTitleLabel(in: cell)!
                expect(title.text).to(equal("happy"))
                expect(naturalWidth("happy", font: title.font)).to(
                    beLessThanOrEqualTo(title.bounds.width),
                    description: "the base-size caption must already fit, or this spec isn't proving 'no shrink needed'"
                )
            }

            // Font/minimumScaleFactor are fixed in `setupUI` regardless of the cell's frame or
            // configured text, so a throwaway zero-frame cell is enough to read them — used
            // below to size a test cell that's wide enough to prove the shrink MECHANISM
            // deterministically, independent of any real device's actual grid column width.
            func liveTitleFont() -> (base: UIFont, minimumScaleFactor: CGFloat) {
                let probe = findTitleLabel(in: EmojiCell(frame: .zero))!
                return (probe.font, probe.minimumScaleFactor)
            }

            it("shrinks (does not truncate) a long caption like 'pasta pastafarian'") {
                let caption = "pasta pastafarian"
                let (baseFont, minimumScaleFactor) = liveTitleFont()
                let floorFont = baseFont.withSize(baseFont.pointSize * minimumScaleFactor)
                let widthAtFloor = naturalWidth(caption, font: floorFont)
                let widthAtBase = naturalWidth(caption, font: baseFont)

                // A cell width strictly between the two: too narrow for the caption at its base
                // size (so the shrink path actually has to engage) but wide enough at the floor
                // size (so it does NOT have to fall back to ellipsis). Real grid cells are
                // narrower (~65-90pt on a phone, 4-per-row) and CAN still legitimately ellipsis a
                // caption this long even at the 11pt floor — that's an expected, separate outcome
                // (see the "absurdly long" spec below), not what this spec is proving.
                let cell = makeCell(width: (widthAtFloor + widthAtBase) / 2)
                let item = EmojiItem(id: "1", type: "feedback_tag", tag: "🍝", label: caption)
                cell.configure(with: item, selected: false)
                cell.layoutIfNeeded()

                let title = findTitleLabel(in: cell)!
                // UILabel always stores the full string; truncation is a draw-time artifact of
                // lineBreakMode, never reflected in `.text` — so this only proves the value made
                // it through unmodified, not that it renders un-truncated (the assertions below do).
                expect(title.text).to(equal(caption))

                expect(naturalWidth(caption, font: title.font)).to(
                    beGreaterThan(title.bounds.width),
                    description: "the caption must NOT already fit at the base size, or this spec doesn't exercise the shrink path"
                )
                expect(naturalWidth(caption, font: floorFont)).to(
                    beLessThanOrEqualTo(title.bounds.width),
                    description: "the floor size must fit without truncating, or adjustsFontSizeToFitWidth can't avoid the ellipsis"
                )
            }

            it("still ellipsises an absurdly long caption once even the floor size doesn't fit") {
                let cell = makeCell()
                let absurd = String(repeating: "supercalifragilisticexpialidocious ", count: 10)
                let item = EmojiItem(id: "1", type: "feedback_tag", tag: "🙂", label: absurd)
                cell.configure(with: item, selected: false)
                cell.layoutIfNeeded()

                let title = findTitleLabel(in: cell)!
                let floorFont = title.font.withSize(title.font.pointSize * title.minimumScaleFactor)
                expect(naturalWidth(absurd, font: floorFont)).to(
                    beGreaterThan(title.bounds.width),
                    description: "the floor must still be too small here, or this spec doesn't exercise the ellipsis fallback"
                )
                expect(title.lineBreakMode).to(equal(.byTruncatingTail))
                expect(title.numberOfLines).to(equal(1))
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

// The emoji glyph label's font point size is EmojiCell.glyphSlotHeight (see EmojiCell.setupUI);
// the caption title label is the only other UILabel in the cell, distinguished by font size.
// `titleLabel.font.pointSize` stays at its base (<=18pt) value even while
// `adjustsFontSizeToFitWidth` shrinks the on-screen rendering, so this stays unambiguous.
private func findTitleLabel(in view: UIView) -> UILabel? {
    return findLabel(in: view, matching: { $0.font.pointSize != EmojiCell.glyphSlotHeight })
}

private func collectImageViews(in view: UIView) -> [UIImageView] {
    var result: [UIImageView] = []
    if let imageView = view as? UIImageView { result.append(imageView) }
    for subview in view.subviews {
        result.append(contentsOf: collectImageViews(in: subview))
    }
    return result
}

private func findImageView(in view: UIView) -> UIImageView? {
    return collectImageViews(in: view).first
}
