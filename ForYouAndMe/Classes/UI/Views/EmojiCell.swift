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
    private static let glyphSlotHeight: CGFloat = 45

    private let emojiLabel = UILabel()
    private let noneImageView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        emojiLabel.font = UIFont.systemFont(ofSize: 35)
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

        // The glyph label and the icon are both arranged subviews so that hiding one removes
        // it from the layout outright. Nesting them in a plain container instead would leave
        // the hidden label still driving the container's size, which collapses the row to the
        // label's (empty) intrinsic height and lets contentView.clipsToBounds crop the icon.
        let stack = UIStackView(arrangedSubviews: [emojiLabel, noneImageView, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.addBlankSpace(space: 4)

        contentView.addSubview(stack)
        stack.autoPinEdgesToSuperviewEdges()

        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        emojiLabel.text = nil
        emojiLabel.isHidden = false
        noneImageView.isHidden = true
        noneImageView.isAccessibilityElement = false
        noneImageView.accessibilityLabel = nil
        titleLabel.text = nil
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
    func configure(with item: EmojiItem?, selected: Bool) {
        let isNoneOption = item == nil
        emojiLabel.text = item?.tag
        emojiLabel.isHidden = isNoneOption
        noneImageView.isHidden = !isNoneOption
        let caption = Self.displayedCaption(for: item)
        // titleLabel is never hidden: the stack is pinned to a fixed-height cell and
        // distributes .fill, so it needs at least one stretchable arranged subview to absorb
        // the slack. Hiding it in the (default) blank-caption state leaves only required
        // heights, which cannot satisfy the cell's required height and breaks a constraint.
        // An empty label renders nothing anyway.
        titleLabel.text = caption
        // Replacing the glyph with an image would otherwise leave the no-emoji option with no
        // accessible content at all once the caption is blank; VoiceOver announced "❌" plus
        // "none" before. Fall back to a literal (there is no EmojiItem.label to read any more)
        // so the announcement survives a study that sets no caption.
        noneImageView.isAccessibilityElement = isNoneOption
        noneImageView.accessibilityLabel = isNoneOption ? (caption.isEmpty ? "none" : caption) : nil
        contentView.backgroundColor = selected ? ColorPalette.color(withType: .inactive) : .clear
    }
}
