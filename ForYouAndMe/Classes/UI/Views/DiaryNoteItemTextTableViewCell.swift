//
//  DiaryNoteTableViewCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import UIKit

class DiaryNoteItemTextTableViewCell: UITableViewCell {
    
    /// This view contains the tag icon and label displayed above the note content.
    private lazy var noteTagContainer: UIStackView = {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 8.0
        container.distribution = .fill
        container.addArrangedSubview(tagIconImageView)
        container.addArrangedSubview(tagLabel)
        container.backgroundColor = .yellow
        container.layer.cornerRadius = 6
        container.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        container.isLayoutMarginsRelativeArrangement = true
        
        return container
    }()
    
    private lazy var tagIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = ImagePalette.image(withName: .reflectionBrainIcon)
        imageView.autoSetDimensions(to: CGSize(width: 10, height: 10))
        return imageView
    }()
    
    private lazy var tagLabel: UILabel = {
        let label = UILabel()
        label.text = "I HAVE NOTICED".uppercased()
        label.font = UIFont.systemFont(ofSize: 8, weight: .medium)
        label.textColor = ColorPalette.color(withType: .primaryText)
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var noteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 22, height: 22))
        return imageView
    }()
    
    private lazy var noteTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var noteDescriptionLabel: UILabel = {
        let label = UILabel()
          label.numberOfLines = 2
          return label
      }()
    
    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ImagePalette.templateImage(withName: .arrowRight)
        imageView.tintColor = ColorPalette.color(withType: .gradientPrimaryEnd)
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return imageView
    }()
    
    private var buttonPressedCallback: NotificationCallback?
        
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        let backgroundView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        let containerView = UIStackView()
        containerView.axis = .horizontal
        containerView.alignment = .center
        containerView.spacing = 8.0
        containerView.distribution = .fill
        
        backgroundView.addArrangedSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges()
        
        containerView.addArrangedSubview(self.noteImageView, horizontalInset: 8.0)
        
        let textView = UIStackView()
        textView.axis = .vertical
        textView.spacing = 4.0
        textView.alignment = .leading
        textView.addArrangedSubview(self.noteTagContainer)
        textView.addArrangedSubview(self.noteTitleLabel)
        textView.addArrangedSubview(self.noteDescriptionLabel)
        
        containerView.addArrangedSubview(textView)
        containerView.addArrangedSubview(self.arrowImageView)
        
        self.contentView.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                       left: Constants.Style.DefaultHorizontalMargins,
                                                                       bottom: 0.0,
                                                                       right: Constants.Style.DefaultHorizontalMargins))
        
        // Enable user interaction on the content view to make sure the cell responds to touch events
        self.contentView.isUserInteractionEnabled = true
        
        // Add Tap Gesture Recognizer to the content view
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.buttonPressed))
        self.contentView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: DiaryNoteItem, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback

        self.updateNoteTitle(data.title ?? "")
        self.updateNoteDescription(data.body ?? "")
        noteImageView.image = ImagePalette.image(withName: .textNoteListImage)
        
        if let diaryType = DiaryNoteableType(rawValue: data.diaryNoteable?.type.lowercased() ?? "none") {
            switch diaryType {
            case .none, .chart:
                self.tagLabel.text = "I Have Noticed"
                self.noteTagContainer.backgroundColor = ColorPalette.color(withType: .noticedColor)
                self.tagLabel.textColor = ColorPalette.color(withType: .noticedTextColor)
                self.tagIconImageView.tintColor = ColorPalette.color(withType: .noticedTextColor)
                self.tagIconImageView.image = ImagePalette.image(withName: .reflectionEyeIcon)
            case .task:
                self.tagLabel.text = "Reflection"
                self.noteTagContainer.backgroundColor = ColorPalette.color(withType: .reflectionColor)
                self.tagLabel.textColor = ColorPalette.color(withType: .reflectionTextColor)
                self.tagIconImageView.tintColor = ColorPalette.color(withType: .reflectionTextColor)
                self.tagIconImageView.image = ImagePalette.image(withName: .reflectionBrainIcon)
            }
        } else {
            self.noteTagContainer.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.buttonPressedCallback?()
    }
    
    // MARK: - Private Methods
    
    private func updateNoteTitle(_ title: String) {
        let attributedString = NSAttributedString.create(withText: title,
                                                         fontStyle: .paragraph,
                                                         colorType: .primaryText,
                                                         textAlignment: .left,
                                                         underlined: false)
        
        self.noteTitleLabel.attributedText = attributedString
    }
    
    private func updateNoteDescription(_ description: String) {
        let attributedString = NSAttributedString.create(withText: description,
                                                         fontStyle: .header3,
                                                         colorType: .primaryText,
                                                         textAlignment: .left,
                                                         underlined: false)
        
        self.noteDescriptionLabel.attributedText = attributedString
    }
}
