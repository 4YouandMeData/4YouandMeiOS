//
//  DiaryNoteTableViewCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import UIKit

class DiaryNoteItemTextTableViewCell: UITableViewCell {
    
    private lazy var noteImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 18, height: 18))
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
