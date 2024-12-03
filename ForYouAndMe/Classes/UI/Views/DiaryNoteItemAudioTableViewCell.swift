//
//  DiaryNoteItemTableViewCell.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import UIKit

class DiaryNoteItemAudioTableViewCell: UITableViewCell {
    
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
    
    private lazy var playButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .audioPlayPreview), for: .normal)
        button.autoSetDimensions(to: CGSize(width: 28, height: 28))
        button.addTarget(self, action: #selector(self.playButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "00:00"
        return label
    }()
    
    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        return slider
    }()
    
    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = ImagePalette.templateImage(withName: .arrowRight)
        imageView.tintColor = ColorPalette.color(withType: .gradientPrimaryEnd)
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 18, height: 18))
        return imageView
    }()
    
    private var buttonPressedCallback: NotificationCallback?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        let backgroundView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        let containerView = UIStackView.create(withAxis: .horizontal, spacing: 10.0)
        containerView.distribution = .fill
        containerView.alignment = .center
        
        backgroundView.addArrangedSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges()
        
        containerView.addArrangedSubview(self.noteImageView, horizontalInset: 8.0)
        
        let playerView = UIStackView()
        playerView.axis = .vertical
        playerView.distribution = .fill
        playerView.addArrangedSubview(self.noteTitleLabel)
        playerView.spacing = 16.0
        
        let audioView = UIStackView()
        audioView.axis = .horizontal
        audioView.alignment = .center
        audioView.distribution = .fill
        audioView.spacing = 8.0
        audioView.addArrangedSubview(self.playButton)
        audioView.addArrangedSubview(self.timeLabel)
        audioView.addArrangedSubview(self.slider)
        
        playerView.addArrangedSubview(audioView)
        
        containerView.addArrangedSubview(playerView)
        containerView.addArrangedSubview(self.arrowImageView)
        
        self.contentView.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                       left: Constants.Style.DefaultHorizontalMargins,
                                                                       bottom: 0.0,
                                                                       right: Constants.Style.DefaultHorizontalMargins))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: DiaryNoteItem, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        
        self.updateNoteTitle(data.title ?? "")
        
        noteImageView.image = ImagePalette.image(withName: .audioNoteListImage)
    }
    
    // MARK: - Actions
    
    @objc private func playButtonPressed() {
        // Placeholder for play button action
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
}
