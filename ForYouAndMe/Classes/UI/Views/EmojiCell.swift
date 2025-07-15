//
//  EmojiCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/07/25.
//

final class EmojiCell: UICollectionViewCell {

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        emojiLabel.font = UIFont.systemFont(ofSize: 40)
        emojiLabel.textAlignment = .center

        titleLabel.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        titleLabel.textColor = .darkGray
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [emojiLabel, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.addBlankSpace(space: 4)

        contentView.addSubview(stack)
        stack.autoPinEdgesToSuperviewEdges()

        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
    }

    func configure(with item: EmojiItem, selected: Bool) {
        emojiLabel.text = item.tag
        titleLabel.text = item.label
        contentView.backgroundColor = selected ? ColorPalette.color(withType: .inactive) : .clear
    }
}
