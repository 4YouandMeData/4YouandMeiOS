//
//  DiaryNoteItemMenstrualTableViewCell.swift
//  Pods
//
//  FUAM-2933 — Compass Log cell for menstrual cycle entries. Displays a
//  drop icon, the title "Menstrual Flow Tracking" and a "From: <date> -
//  To: <date>" subtitle (range collapses to "..." when the bleeding
//  sequence has not yet been closed by a `no` entry).
//

import UIKit
import PureLayout

class DiaryNoteItemMenstrualTableViewCell: UITableViewCell {

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    private lazy var iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = ImagePalette.templateImage(withName: .menstrualCycleIcon)
        iv.tintColor = ColorPalette.color(withType: .primaryText)
        iv.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = ColorPalette.color(withType: .primaryText)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = ColorPalette.color(withType: .fourthText)
        return label
    }()

    private lazy var arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = ImagePalette.templateImage(withName: .arrowRight)
        iv.tintColor = ColorPalette.color(withType: .primary)
        iv.contentMode = .scaleAspectFit
        iv.autoSetDimensions(to: CGSize(width: 18, height: 18))
        return iv
    }()

    private var buttonPressedCallback: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.addArrangedSubview(iconImageView)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(arrowImageView)

        contentView.addSubview(row)
        row.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 12,
                                                            left: Constants.Style.DefaultHorizontalMargins,
                                                            bottom: 12,
                                                            right: Constants.Style.DefaultHorizontalMargins))

        contentView.isUserInteractionEnabled = true
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGR)
    }

    /// Configure cell from a MenstrualSequence: title fixed, subtitle is the
    /// "From: <start> - To: <end>" range. End date is replaced with "..."
    /// for sequences that have not been closed by a `no` entry yet.
    public func display(sequence: MenstrualSequence,
                        isOpenEnded: Bool = false,
                        onTap: @escaping () -> Void) {
        self.buttonPressedCallback = onTap

        titleLabel.text = StringsProvider.string(forKey: .diaryNoteMenstrualCellTitle)

        let fromPrefix = StringsProvider.string(forKey: .diaryNoteMenstrualCellFrom)
        let toPrefix = StringsProvider.string(forKey: .diaryNoteMenstrualCellTo)
        let startString = Self.dayMonthFormatter.string(from: sequence.startDate)
        let endString: String
        if isOpenEnded {
            endString = "..."
        } else {
            endString = Self.dayMonthFormatter.string(from: sequence.endDate)
        }
        subtitleLabel.text = "\(fromPrefix) \(startString) - \(toPrefix) \(endString)"
    }

    @objc private func cellTapped() {
        buttonPressedCallback?()
    }
}
