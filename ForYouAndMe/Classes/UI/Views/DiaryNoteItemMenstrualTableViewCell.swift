//
//  DiaryNoteItemMenstrualTableViewCell.swift
//  Pods
//
//  FUAM-2933 — Compass Log cell for menstrual cycle entries. Displays a
//  single-date or aggregated date range produced by MenstrualSequence
//  grouping (consecutive bleeding=yes entries collapse into one row).
//

import UIKit
import PureLayout

/// Cell for displaying menstrual cycle diary entries (single or aggregated).
class DiaryNoteItemMenstrualTableViewCell: UITableViewCell {

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private lazy var emojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    private lazy var noteTagContainer: UIStackView = {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 4.0
        container.distribution = .fill
        container.addArrangedSubview(tagIconImageView)
        container.addArrangedSubview(tagLabel)
        container.backgroundColor = UIColor.init(hexString: Constants.Style.MenstrualColorBackground)
        container.layer.cornerRadius = 6
        container.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        container.isLayoutMarginsRelativeArrangement = true
        return container
    }()

    private lazy var tagIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = ImagePalette.templateImage(withName: .menstrualCycleIcon)
        imageView.tintColor = UIColor.init(hexString: Constants.Style.MenstrualColorText)
        imageView.autoSetDimensions(to: CGSize(width: 10, height: 10))
        return imageView
    }()

    private lazy var tagLabel: UILabel = {
        let label = UILabel()
        label.text = StringsProvider.string(forKey: .diaryNoteTagMenstrual)
        label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
        label.textColor = UIColor.init(hexString: Constants.Style.MenstrualColorText)
        label.numberOfLines = 1
        return label
    }()

    private lazy var noteImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = ImagePalette.templateImage(withName: .menstrualCycleIcon)
        iv.tintColor = UIColor.init(hexString: Constants.Style.MenstrualColorText)
        iv.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return iv
    }()

    private lazy var noteTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 1
        return lbl
    }()

    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ImagePalette.templateImage(withName: .arrowRight)
        imageView.tintColor = ColorPalette.color(withType: .gradientPrimaryEnd)
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return imageView
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

        let backgroundView = UIStackView.create(withAxis: .vertical, spacing: 8.0)

        let containerView = UIStackView.create(withAxis: .horizontal, spacing: 10.0)
        containerView.distribution = .fill
        containerView.alignment = .center

        backgroundView.addArrangedSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges()

        containerView.addArrangedSubview(self.noteImageView, horizontalInset: 8.0)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 8.0

        let tagRow = UIStackView()
        tagRow.axis = .horizontal
        tagRow.spacing = 4.0
        tagRow.alignment = .center
        tagRow.addArrangedSubview(self.noteTagContainer)
        tagRow.addArrangedSubview(self.emojiLabel)

        textStack.addArrangedSubview(tagRow)
        textStack.addArrangedSubview(noteTitleLabel)

        containerView.addArrangedSubview(textStack)
        containerView.addArrangedSubview(self.arrowImageView)

        self.contentView.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                       left: Constants.Style.DefaultHorizontalMargins,
                                                                       bottom: 0.0,
                                                                       right: Constants.Style.DefaultHorizontalMargins))

        self.contentView.isUserInteractionEnabled = true

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGR)
    }

    /// Configure cell for a menstrual sequence (single or aggregated).
    /// Date-range string is built locally — strings file holds plain labels.
    public func display(sequence: MenstrualSequence, onTap: @escaping () -> Void) {
        self.buttonPressedCallback = onTap

        let title: String
        if sequence.isAggregated {
            let start = Self.dayMonthFormatter.string(from: sequence.startDate)
            let end = Self.dayMonthFormatter.string(from: sequence.endDate)
            title = "\(start) – \(end)"
        } else {
            title = Self.dayMonthFormatter.string(from: sequence.startDate)
        }
        self.updateNoteTitle(title)

        if let emoji = sequence.representative.feedbackTags?.last {
            emojiLabel.text = emoji.tag
            emojiLabel.isHidden = false
        } else {
            emojiLabel.text = nil
            emojiLabel.isHidden = true
        }
    }

    @objc private func cellTapped() {
        buttonPressedCallback?()
    }

    private func updateNoteTitle(_ title: String) {
        let attributedString = NSAttributedString.create(withText: title,
                                                         fontStyle: .paragraph,
                                                         colorType: .primaryText,
                                                         textAlignment: .left,
                                                         underlined: false)
        self.noteTitleLabel.attributedText = attributedString
    }
}
