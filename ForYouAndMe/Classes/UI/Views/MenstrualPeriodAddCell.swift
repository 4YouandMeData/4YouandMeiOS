//
//  MenstrualPeriodAddCell.swift
//  ForYouAndMe
//
//  FUAM-2934 — Row at the top of the menstrual period detail table that
//  triggers the wizard in add mode. Looks like a regular row so it scrolls
//  together with the entries (rather than sitting in the static header).
//

import UIKit
import PureLayout

final class MenstrualPeriodAddCell: UITableViewCell {

    private let plusImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = ImagePalette.templateImage(withName: .plusIcon)
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ColorPalette.color(withType: .primary)
        iv.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = StringsProvider.string(forKey: .menstrualDetailAddButton)
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = ColorPalette.color(withType: .primary)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.addArrangedSubview(plusImageView)
        row.addArrangedSubview(titleLabel)

        contentView.addSubview(row)
        row.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16,
                                                            left: Constants.Style.DefaultHorizontalMargins,
                                                            bottom: 16,
                                                            right: Constants.Style.DefaultHorizontalMargins))
    }
}
