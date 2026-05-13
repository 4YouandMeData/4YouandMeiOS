//
//  DiaryNoteItemMenstrualTableViewCell.swift
//  Pods
//
//  FUAM-2933 / FUAM-2934 — Compass Log cell for menstrual cycle entries.
//  Displays a drop icon, the title "Menstrual Flow Tracking" and a
//  "From: <date> - To: <date>" subtitle. The range comes from the BE
//  `series_meta` (v0.12.5) on the compressed row; `to` collapses to "..."
//  while the series is ongoing. Non-anchor menstrual rows (a closing `no`,
//  an orphan `other`) carry no `series_meta` and render as a single day.
//

import UIKit
import PureLayout

class DiaryNoteItemMenstrualTableViewCell: UITableViewCell {

    /// Series bounds are date-only values anchored at UTC midnight — format in
    /// UTC so the displayed day matches the BE date regardless of device zone.
    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
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
        // Allow wrapping so the "To: <date>" half is never clipped on narrow
        // screens — the full From/To range must always stay readable (FUAM-2934).
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
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

    /// Configure from a Compass Log diary note. Title is fixed; the subtitle
    /// is the "From: <start> - To: <end>" range read from `seriesMeta`
    /// ("..." while ongoing). Rows without `seriesMeta` render as a single day.
    public func display(diaryNote: DiaryNoteItem,
                        onTap: @escaping () -> Void) {
        self.buttonPressedCallback = onTap

        titleLabel.text = StringsProvider.string(forKey: .diaryNoteMenstrualCellTitle)

        let fromPrefix = StringsProvider.string(forKey: .diaryNoteMenstrualCellFrom)
        let toPrefix = StringsProvider.string(forKey: .diaryNoteMenstrualCellTo)

        let startDate: Date
        let endString: String
        if let meta = diaryNote.seriesMeta {
            startDate = meta.from
            endString = meta.ongoing ? "..." : Self.dayMonthFormatter.string(from: meta.to ?? meta.from)
        } else {
            startDate = diaryNote.diaryNoteId
            endString = Self.dayMonthFormatter.string(from: diaryNote.diaryNoteId)
        }
        let startString = Self.dayMonthFormatter.string(from: startDate)
        subtitleLabel.text = "\(fromPrefix) \(startString) - \(toPrefix) \(endString)"
    }

    @objc private func cellTapped() {
        buttonPressedCallback?()
    }
}
