//
//  MenstrualPeriodEntryCell.swift
//  ForYouAndMe
//
//  FUAM-2934 — Row in the menstrual period detail screen.
//  Shows the bleeding date and an optional note preview.
//

import UIKit
import PureLayout

final class MenstrualPeriodEntryCell: UITableViewCell {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = ImagePalette.templateImage(withName: .menstrualCycleIcon)
        iv.tintColor = ColorPalette.color(withType: .primary)
        iv.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return iv
    }()

    private let dateLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 1
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }()

    private let noteLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 1
        lbl.font = .preferredFont(forTextStyle: .footnote)
        lbl.textColor = ColorPalette.color(withType: .fourthText)
        return lbl
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.addArrangedSubview(dateLabel)
        textStack.addArrangedSubview(noteLabel)

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(textStack)

        contentView.addSubview(row)
        row.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 12,
                                                            left: Constants.Style.DefaultHorizontalMargins,
                                                            bottom: 12,
                                                            right: Constants.Style.DefaultHorizontalMargins))
    }

    func display(date: Date, note: String?) {
        dateLabel.text = Self.dateFormatter.string(from: date)
        if let note = note, note.isEmpty == false {
            noteLabel.text = note
            noteLabel.isHidden = false
        } else {
            noteLabel.text = nil
            noteLabel.isHidden = true
        }
    }
}
