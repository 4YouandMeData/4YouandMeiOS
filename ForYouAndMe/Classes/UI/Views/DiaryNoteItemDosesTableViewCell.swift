//
//  DiaryNoteItemDosesTableViewCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/06/25.
//

import UIKit

/// Cell for displaying "Doses" diary entries
class DiaryNoteItemDosesTableViewCell: UITableViewCell {
    // MARK: - Views
    private lazy var noteTagContainer: UIStackView = {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 4.0
        container.distribution = .fill
        container.addArrangedSubview(tagIconImageView)
        container.addArrangedSubview(tagLabel)
        container.backgroundColor = UIColor.init(hexString: Constants.Style.DosesColorBackground)
        container.layer.cornerRadius = 6
        container.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        container.isLayoutMarginsRelativeArrangement = true
        
        return container
    }()
    
    private lazy var tagIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = ImagePalette.templateImage(withName: .siringeIcon)
        imageView.tintColor = UIColor.init(hexString: Constants.Style.DosesColorText)
        imageView.autoSetDimensions(to: CGSize(width: 10, height: 10))
        return imageView
    }()
    
    private lazy var tagLabel: UILabel = {
        let label = UILabel()
        label.text = "My Doses"
        label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
        label.textColor = UIColor.init(hexString: Constants.Style.DosesColorText)
        label.numberOfLines = 1
        return label
    }()

    private lazy var noteImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.image = ImagePalette.image(withName: .surveyIcon)
        iv.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return iv
    }()

    private lazy var noteTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.preferredFont(forTextStyle: .body)
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

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
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
        textStack.spacing = 8.0
        textStack.alignment = .leading
        textStack.addArrangedSubview(noteTagContainer)
        textStack.addArrangedSubview(noteTitleLabel)
        containerView.addArrangedSubview(textStack)
        
        containerView.addArrangedSubview(self.arrowImageView)

        self.contentView.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                       left: Constants.Style.DefaultHorizontalMargins,
                                                                       bottom: 0.0,
                                                                       right: Constants.Style.DefaultHorizontalMargins))
        
        // Enable user interaction on the content view to make sure the cell responds to touch events
        self.contentView.isUserInteractionEnabled = true

        let tapGR = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
        contentView.addGestureRecognizer(tapGR)
    }

    // MARK: - Public
    /// Configure cell with DiaryNoteItem of type .doses
    public func display(data: DiaryNoteItem, onTap: @escaping () -> Void) {
        self.buttonPressedCallback = onTap
        if let body = data.body {
            noteTitleLabel.text = body
        } else {
            noteTitleLabel.text = "Survey Submitted"
        }
    }

    // MARK: - Actions
    @objc private func cellTapped() {
        buttonPressedCallback?()
    }
}
