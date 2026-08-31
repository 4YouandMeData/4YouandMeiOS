//
//  EmojiCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/07/25.
//

final class EmojiCell: UICollectionViewCell {

    // FUAM-3857: the glyph label and the icon share one slot size so the caption sits at the
    // same height regardless of which branch renders — previously 45x45 for the icon next to
    // an unrelated ~41pt glyph line box.
    //
    // FUAM-3857 round 8: this ALSO doubles as the emoji glyph's font point size — the shared
    // contract agreed with Android is "one glyph box constant on each platform, the emoji font
    // size derived as box / ink-overfill-ratio measured on THAT platform's own emoji font"
    // (Android's Noto overshoots by ~3.3%; Apple Color Emoji does not, see below). The no-emoji
    // icon's 45x45pt canvas (its drawn circle measures 41, per the designer's export) is the
    // canonical box; a real emoji must render at that same visual size (matching the box, not
    // just the 41pt circle).
    //
    // Measured on-device (iPhone 15 simulator, Apple Color Emoji), three ways — this file's own
    // pixel scan of a rendered UILabel, an independent `ImageMagick -trim` cross-check at two
    // fuzz thresholds, and a visual overlay against the icon at 4x zoom — all agreeing: a
    // circular emoji's (🙂 😢 ❌) drawn ink height tracks UIFont's point size almost exactly
    // (ratio ~1.00 at every size tried, 35-45pt), NOT the ~1.16 initially assumed. So the
    // overfill ratio is ~1.00 here and `UIFont.systemFont(ofSize: 45)` renders a ~45pt-tall
    // glyph directly, no compensation needed — unlike Android, which had to divide its 45sp box
    // by its measured 1.033 ratio to land on ~43.56sp. (A compound emoji like 🥵 — face plus
    // separate droplets — measured slightly smaller, ~96-98% of point size; normal glyph-shape
    // variance, not evidence of a different ratio for the common case.) One constant drives both
    // the icon and the emoji font size here, so they can't drift apart.
    //
    // Round 9 (Jules pushed back on trusting a measured ratio, since Android's turned out wrong
    // on-device): re-verified with CoreText's own ink metric —
    // `CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)` — which is authoritative in a way
    // a pixel scan isn't. At 45pt it reports ~45.0001pt of ink for 🙂, 😡 AND 🍝 alike: Apple
    // defines a color emoji glyph's design box as exactly its point size, for every glyph,
    // regardless of how much of that box any one glyph's artwork actually paints. (For
    // reference, `boundingRect(with:options:)` WITHOUT `.usesDeviceMetrics` reports ~53.7pt at
    // the same 45pt — that's the line's layout box padded for ascent/descent/leading, not what
    // gets visually compared against the icon; adding `.usesDeviceMetrics` back brings it to
    // ~45.0001pt too, matching the CoreText ink metric.) A raw pixel scan of 🍝's rendered
    // bitmap, by contrast, found only ~36.7pt of visible ink — spaghetti is wide, not tall; a
    // per-glyph artwork fact, the same reason "i" and "W" don't paint equally tall in any font,
    // and not something a font-wide constant could or should chase. Conclusion: unlike Android's
    // Noto emoji, which overfills its box as a WHOLE FONT (fixable with one constant), Apple
    // Color Emoji's box already equals its point size — there is nothing here for a runtime
    // measure-then-solve calibration to correct, so this file deliberately keeps the one
    // constant instead of adding that machinery. `EmojiCellSpec` pins this down two ways: a
    // CoreText-ink-metric test with no calibration involved, and a live-layout test that renders
    // both branches and asserts the glyph box and the icon box come out equal (the box, not
    // individual glyph artwork — see the spec's comment for why that's the right level).
    //
    // Internal (not private): the test target reads it too, so specs assert against the real
    // value instead of a second hardcoded copy of "45" that could silently drift from this one.
    static let glyphSlotHeight: CGFloat = 45

    // FUAM-3857 round 8: Jules requires at least 2pt of shrink below the caption's base size
    // before it falls back to ellipsis.
    static let captionMinShrinkPoints: CGFloat = 2

    // FUAM-3857 round 8: 11pt is the ABSOLUTE floor coordinated with Android (11sp there,
    // against Android's 14sp base — 3sp of margin over the 2sp minimum). iOS's `.header3` base
    // is 13pt at the default content size category (see FontPalette.FontStyle.defaultData), so
    // 11pt gives exactly `captionMinShrinkPoints` of margin here — zero to spare, unlike
    // Android's. `minimumScaleFactor` is still derived from the label's LIVE font at configure
    // time (not this constant divided by a hardcoded "13"), so it stays correct as Dynamic Type
    // scales the base up toward the 18pt cap.
    static let captionFloorPointSize: CGFloat = 11

    // FUAM-3740 (Jules): the selection highlight must be inset by the SAME amount on all four
    // sides — a square when no option in the grid carries a caption, a vertical rectangle as
    // soon as one does. It used to be the cell's own `contentView`, i.e. the whole grid tile:
    // ~5pt of slack either side of the 45pt glyph box horizontally, none above it and ~19pt
    // below. So it becomes its own view, sized around the content, and the inset is derived
    // from the horizontal slack the tile already has (`selectionInset(forCellWidth:)`) rather
    // than being a new magic number. Mirrors the Android dialog's `EmojiItem` column.
    private let highlightView = UIView()

    private let emojiLabel = UILabel()
    private let noneImageView = UIImageView()
    private let titleLabel = UILabel()

    private var stackTopConstraint: NSLayoutConstraint?
    private var stackBottomConstraint: NSLayoutConstraint?

    /// The equal inset between the selection highlight and the `glyphSlotHeight`-tall glyph
    /// box. It is exactly the horizontal slack the tile already leaves around that box, so the
    /// highlight keeps its current width and, with no caption row, comes out square.
    static func selectionInset(forCellWidth cellWidth: CGFloat) -> CGFloat {
        return max(0, (cellWidth - Self.glyphSlotHeight) / 2.0)
    }

    /// Vertical spacing between the glyph slot and the caption row (the stack's spacing).
    static let captionSpacing: CGFloat = 4

    /// One line of the caption's base font. Fixed per tile so every caption row in a grid is
    /// the same height whether its caption is empty, short, or shrunk to fit — and so
    /// `EmojiPopupViewController` can size a row without laying a cell out first.
    static var captionRowHeight: CGFloat {
        return FontPalette.fontStyleData(forStyle: .header3, maximumPointSize: 18).font.lineHeight
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        emojiLabel.font = UIFont.systemFont(ofSize: Self.glyphSlotHeight)
        emojiLabel.textAlignment = .center
        emojiLabel.autoSetDimension(.height, toSize: Self.glyphSlotHeight)

        noneImageView.image = ImagePalette.image(withName: .emojiNone)
        noneImageView.contentMode = .scaleAspectFit
        noneImageView.autoSetDimensions(to: CGSize(width: Self.glyphSlotHeight, height: Self.glyphSlotHeight))
        noneImageView.isHidden = true

        // FUAM-3857: capped so this fixed-size, clipping cell doesn't shrink below its
        // required content floor at accessibility text sizes (see FontPalette.fontStyleData).
        titleLabel.font = FontPalette.fontStyleData(forStyle: .header3, maximumPointSize: 18).font
        titleLabel.textColor = .darkGray
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        // FUAM-3857 round 8: a long caption (e.g. "pasta pastafarian") shrinks to fit before it
        // ellipsises, down to `captionFloorPointSize`. Below that floor, `.byTruncatingTail`
        // takes back over — confirmed empirically (not assumed) to already be UILabel's own
        // default, but set explicitly here so it can't silently drift.
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.lineBreakMode = .byTruncatingTail
        let baseCaptionPointSize = titleLabel.font.pointSize
        // Guards `minimumScaleFactor` against ever exceeding 1.0 (which UILabel would treat as
        // "no shrink") if a future `.header3` change ever drops the base below the floor — see
        // `captionFloorPointSize`'s doc comment on what that would mean for the 2pt requirement.
        let shrinkMargin = baseCaptionPointSize - Self.captionFloorPointSize
        assert(shrinkMargin >= Self.captionMinShrinkPoints,
               "caption floor gives only \(shrinkMargin)pt of shrink vs. base \(baseCaptionPointSize)pt — recheck with Android")
        let effectiveFloor = min(Self.captionFloorPointSize, baseCaptionPointSize - Self.captionMinShrinkPoints)
        titleLabel.minimumScaleFactor = max(effectiveFloor, 1) / baseCaptionPointSize
        // FUAM-3740: the stack now hugs its content instead of being stretched to fill a fixed
        // cell height, so the caption row no longer gets a uniform height for free. Pin it to
        // one line of the base font: every tile's caption row is then the same height whether
        // the caption is empty, short, or shrunk to fit — which is what keeps the glyphs across
        // a row on one line (the FUAM-3857 round-10 requirement).
        titleLabel.autoSetDimension(.height, toSize: Self.captionRowHeight)

        // The glyph label and the icon are both arranged subviews so that hiding one removes
        // it from the layout outright. Nesting them in a plain container instead would leave
        // the hidden label still driving the container's size, which collapses the row to the
        // label's (empty) intrinsic height and lets contentView.clipsToBounds crop the icon.
        let stack = UIStackView(arrangedSubviews: [emojiLabel, noneImageView, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Self.captionSpacing

        // FUAM-3740: the highlight wraps the content with an equal inset on all four sides
        // instead of being the whole tile. The old trailing 4pt blank space is gone with it —
        // it only existed to give `.fill` something to absorb the fixed cell height's slack,
        // and it would have made the bottom inset 4pt larger than the other three.
        contentView.addSubview(highlightView)
        highlightView.autoPinEdge(toSuperviewEdge: .leading)
        highlightView.autoPinEdge(toSuperviewEdge: .trailing)
        highlightView.autoPinEdge(toSuperviewEdge: .top)
        highlightView.layer.cornerRadius = 8
        highlightView.clipsToBounds = true

        highlightView.addSubview(stack)
        stack.autoPinEdge(toSuperviewEdge: .leading)
        stack.autoPinEdge(toSuperviewEdge: .trailing)
        self.stackTopConstraint = stack.autoPinEdge(toSuperviewEdge: .top)
        self.stackBottomConstraint = stack.autoPinEdge(toSuperviewEdge: .bottom)

        // FUAM-3857 round 8: the stack's cross-axis alignment is `.center`, which only
        // centers arranged subviews — it does NOT constrain their width — so titleLabel would
        // otherwise size to its own intrinsic (full, unshrunk) text width and just get cropped
        // by `contentView.clipsToBounds`, with `adjustsFontSizeToFitWidth` never triggering
        // (nothing is actually narrower than the text). Pin it to the full cell width so
        // shrink-then-ellipsis has a real width to shrink against.
        titleLabel.autoMatch(.width, to: .width, of: contentView)

        // FUAM-3740: the tile itself must not clip any more — the highlight is what has the
        // corner radius, and the glyph label's line box is a hair wider than the 45pt glyph
        // slot it renders.
        contentView.clipsToBounds = false
    }

    override func layoutSubviews() {
        let inset = Self.selectionInset(forCellWidth: self.bounds.width)
        self.stackTopConstraint?.constant = inset
        self.stackBottomConstraint?.constant = -inset
        super.layoutSubviews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        emojiLabel.text = nil
        emojiLabel.isHidden = false
        noneImageView.isHidden = true
        noneImageView.isAccessibilityElement = false
        noneImageView.accessibilityLabel = nil
        titleLabel.text = nil
        titleLabel.isHidden = false
        highlightView.backgroundColor = .clear
    }

    // FUAM-3857: the caption for an option. `item == nil` IS the no-emoji option — its
    // caption comes from the study-configurable EMOJI_NONE_LABEL string; every other item
    // shows its own `label` verbatim. Blank/whitespace-only captions count as "no caption" on
    // both platforms (Android already uses isNotBlank() semantics), and this is the one place
    // that decides it, shared by `configure` here and `EmojiPopupViewController`'s row-height
    // decision — so the two can't drift apart on what counts as "has a caption".
    static func displayedCaption(for item: EmojiItem?) -> String {
        // Two branches, deliberately not `item?.label ?? …`: that flattens to String?, so the
        // fallback would also fire for a REAL item whose label is nil, printing the no-emoji
        // caption under every unlabelled study emoji.
        let raw: String
        if let item = item {
            raw = item.label ?? ""
        } else {
            raw = StringsProvider.string(forKey: .emojiNoneLabel)
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : raw
    }

    // FUAM-3857: `item == nil` is the no-emoji option — there is no sentinel `EmojiItem`
    // standing in for it. A real study emoji, even one captioned "None" or tagged "❌", is an
    // ordinary `Optional.some` and renders as itself.
    /// - Parameter reservesCaptionRow: whether the grid this cell belongs to has any captions
    ///   at all. FUAM-3740: it is a property of the WHOLE grid, never of the single item —
    ///   otherwise an unlabelled emoji sitting next to labelled ones would get a square
    ///   highlight while its neighbours got rectangles, and its glyph would sit on a different
    ///   line. `EmojiPopupViewController.hasCaptions` is the single source of truth.
    func configure(with item: EmojiItem?, selected: Bool, reservesCaptionRow: Bool = true) {
        let isNoneOption = item == nil
        titleLabel.isHidden = !reservesCaptionRow
        emojiLabel.text = item?.tag
        emojiLabel.isHidden = isNoneOption
        noneImageView.isHidden = !isNoneOption
        // FUAM-3857: the icon's baked-in grey (#D9D9D9) sits almost on top of the selected-cell
        // background (ColorPalette .inactive — #DFDFDF light / #3A3A3C dark by default), so the
        // icon all but disappears once its tile is selected, same as the Android bug this
        // mirrors. Tint it white ONLY while selected via `.alwaysTemplate`; the rest of the time
        // it keeps rendering with its own baked colour (`.alwaysOriginal`) — the asset lives
        // outside `Templates/` specifically so it is never blanket-tinted.
        if isNoneOption {
            let baseImage = ImagePalette.image(withName: .emojiNone)
            noneImageView.image = selected ? baseImage?.withRenderingMode(.alwaysTemplate) : baseImage?.withRenderingMode(.alwaysOriginal)
            noneImageView.tintColor = .white
        }
        let caption = Self.displayedCaption(for: item)
        // Kept visible (just blank) whenever the grid reserves a caption row, so every tile in
        // that grid keeps the same height and the glyphs stay on one line. It is only hidden
        // when NO option in the grid has a caption — that is what makes the highlight square.
        titleLabel.text = caption
        // Replacing the glyph with an image would otherwise leave the no-emoji option with no
        // accessible content at all once the caption is blank; VoiceOver announced "❌" plus
        // "none" before. Fall back to a literal (there is no EmojiItem.label to read any more)
        // so the announcement survives a study that sets no caption.
        noneImageView.isAccessibilityElement = isNoneOption
        noneImageView.accessibilityLabel = isNoneOption ? (caption.isEmpty ? "none" : caption) : nil
        highlightView.backgroundColor = selected ? ColorPalette.color(withType: .inactive) : .clear
    }
}
