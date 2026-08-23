//
//  EmojiCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/07/25.
//

final class EmojiCell: UICollectionViewCell {

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

        noneImageView.image = ImagePalette.image(withName: .emojiNone)
        noneImageView.contentMode = .scaleAspectFit
        noneImageView.autoSetDimensions(to: CGSize(width: 45, height: 45))
        noneImageView.isHidden = true

        titleLabel.font = FontPalette.fontStyleData(forStyle: .header3).font
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

    // FUAM-3857: `isNoneOption` is supplied by the caller (`EmojiPopUpViewController`, which
    // owns the sentinel's insertion and therefore its position), not derived from `item.label`
    // here. A real study emoji configured with the label "none" must still render as itself.
    func configure(with item: EmojiItem, isNoneOption: Bool, selected: Bool) {
        emojiLabel.text = isNoneOption ? nil : item.tag
        emojiLabel.isHidden = isNoneOption
        noneImageView.isHidden = !isNoneOption
        // FUAM-3857: for the sentinel the caption comes from the study-configurable
        // EMOJI_NONE_LABEL and is blank unless a study sets it; every other item keeps
        // showing its own label verbatim. titleLabel is never hidden: the stack is pinned to
        // an 80pt cell and distributes .fill, so it needs at least one stretchable arranged
        // subview to absorb the slack. Hiding it in the (default) blank-caption sentinel
        // state leaves only required heights — the 45pt icon and the 4pt blank space — which
        // cannot satisfy the required 80pt, so Auto Layout breaks a constraint and the icon
        // is mispositioned or stretched. An empty label renders nothing anyway.
        titleLabel.text = item.displayedCaption(isNoneOption: isNoneOption)
        // Replacing the glyph with an image would otherwise leave the sentinel with no
        // accessible content at all once the caption is blank; VoiceOver announced "❌" plus
        // "none" before. Fall back to the internal label so the announcement survives a
        // study that sets no caption.
        noneImageView.isAccessibilityElement = isNoneOption
        if isNoneOption {
            let caption = titleLabel.text ?? ""
            noneImageView.accessibilityLabel = caption.isEmpty ? item.label : caption
        } else {
            noneImageView.accessibilityLabel = nil
        }
        contentView.backgroundColor = selected ? ColorPalette.color(withType: .inactive) : .clear
    }
}
