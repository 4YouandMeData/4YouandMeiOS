//
//  MenstrualPeriodEntryCell.swift
//  ForYouAndMe
//
//  FUAM-2934 — Row in the menstrual period detail screen.
//  Shows the bleeding date with a flow-specific droplet icon, an optional
//  note preview, and a chevron suggesting the row will eventually become
//  tappable. Editing individual entries is out of scope for this release.
//

import UIKit
import PureLayout

final class MenstrualPeriodEntryCell: UITableViewCell {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Per Figma: "MM / dd / yyyy" with single spaces around slashes.
        formatter.dateFormat = "MM / dd / yyyy"
        return formatter
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = ColorPalette.color(withType: .primaryText)
        iv.autoSetDimensions(to: CGSize(width: 28, height: 28))
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
        lbl.lineBreakMode = .byTruncatingTail
        lbl.font = .preferredFont(forTextStyle: .footnote)
        lbl.textColor = ColorPalette.color(withType: .fourthText)
        return lbl
    }()

    private let emojiLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 22)
        label.textAlignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.isHidden = true
        return label
    }()

    private let chevronView: UIImageView = {
        let iv = UIImageView()
        iv.image = ImagePalette.templateImage(withName: .arrowRight)
        iv.tintColor = ColorPalette.color(withType: .primary)
        iv.contentMode = .scaleAspectFit
        iv.autoSetDimensions(to: CGSize(width: 18, height: 18))
        return iv
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
        row.spacing = 16
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(textStack)
        row.addArrangedSubview(emojiLabel)
        row.addArrangedSubview(chevronView)

        contentView.addSubview(row)
        row.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 14,
                                                            left: Constants.Style.DefaultHorizontalMargins,
                                                            bottom: 14,
                                                            right: Constants.Style.DefaultHorizontalMargins))
    }

    /// Configure the cell from an entry. The icon picks the matching flow
    /// asset; the menstrual cycle icon is used as a fallback when the
    /// payload cannot be parsed.
    func display(entry: DiaryNoteItem) {
        dateLabel.text = Self.dateFormatter.string(from: entry.diaryNoteId)

        if case let .menstrual(_, flowAmount, _, _, payloadNote) = entry.payload {
            if let amount = MenstrualFlowAmount(rawValue: flowAmount) {
                iconView.image = ImagePalette.templateImage(withName: amount.iconName)
            } else {
                iconView.image = ImagePalette.templateImage(withName: .menstrualCycleIcon)
            }
            applyNote(payloadNote)
        } else {
            iconView.image = ImagePalette.templateImage(withName: .menstrualCycleIcon)
            applyNote(entry.body)
        }

        applyEmoji(from: entry.feedbackTags)
    }

    /// Legacy entry point kept for the existing FUAM-2934 spec until it is
    /// migrated to the new signature.
    func display(date: Date, note: String?) {
        dateLabel.text = Self.dateFormatter.string(from: date)
        iconView.image = ImagePalette.templateImage(withName: .menstrualCycleIcon)
        applyNote(note)
    }

    private func applyNote(_ note: String?) {
        if let note = note, note.isEmpty == false {
            noteLabel.text = note
            noteLabel.isHidden = false
        } else {
            noteLabel.text = nil
            noteLabel.isHidden = true
        }
    }

    private func applyEmoji(from tags: [EmojiItem]?) {
        if let emoji = tags?.last, emoji.label != "none" {
            emojiLabel.text = emoji.tag
            emojiLabel.isHidden = false
        } else {
            emojiLabel.text = nil
            emojiLabel.isHidden = true
        }
    }
}
