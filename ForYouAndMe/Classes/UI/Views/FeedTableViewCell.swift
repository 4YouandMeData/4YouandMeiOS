//
//  FeedTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit

class FeedTableViewCell: UITableViewCell {
    
    private let gradientView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0))
    }()
    
    private lazy var feedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.height, toSize: 56.0)
        return imageView
    }()
    
    private lazy var feedTitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var feedDescriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var buttonView: GenericButtonView = {
        let button = GenericButtonView(withTextStyleCategory: .feed, fillWidth: false, topInset: 30.0, bottomInset: 0.0)
        button.addTarget(target: self, action: #selector(self.buttonPressed))
        return button
    }()
    
    private var buttonPressedCallback: NotificationCallback?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.backgroundColor = .clear
        
        // Panel View
        let backgroundView = UIView()
        self.contentView.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24.0,
                                                                       left: Constants.Style.DefaultHorizontalMargins,
                                                                       bottom: 24.0,
                                                                       right: Constants.Style.DefaultHorizontalMargins))
        backgroundView.addShadowCell()
        
        let panelView = UIView()
        panelView.addGradientView(self.gradientView)
        panelView.layer.cornerRadius = 8.0
        panelView.layer.masksToBounds = true
        backgroundView.addSubview(panelView)
        panelView.autoPinEdgesToSuperviewEdges()
        
        // Stack View
        let stackView = UIStackView()
        stackView.axis = .vertical
        panelView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 30.0, left: 16.0, bottom: 30.0, right: 16.0))
        
        // Content
        stackView.addArrangedSubview(self.feedImageView)
        stackView.addBlankSpace(space: 18.0)
        stackView.addArrangedSubview(self.feedTitleLabel)
        stackView.addBlankSpace(space: 12.0)
        stackView.addArrangedSubview(self.feedDescriptionLabel)
        stackView.addArrangedSubview(self.buttonView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: Activity, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        self.gradientView.updateParameters(colors: [data.startColor ?? ColorPalette.color(withType: .primary),
                                                    data.endColor ?? ColorPalette.color(withType: .gradientPrimaryEnd)])
        
        self.setFeedImage(image: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        if nil != data.taskType {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .activityButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            assert(data.buttonText == nil, "Existing button text for activity without activity type")
            self.buttonView.isHidden = true
        }
    }
    
    public func display(data: Survey, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        self.gradientView.updateParameters(colors: [data.startColor ?? ColorPalette.color(withType: .primary),
                                                    data.endColor ?? ColorPalette.color(withType: .gradientPrimaryEnd)])
        
        self.setFeedImage(image: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        let buttonText = data.buttonText ?? StringsProvider.string(forKey: .surveyButtonDefault)
        self.buttonView.isHidden = false
        self.buttonView.setButtonText(buttonText)
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.buttonPressedCallback?()
    }
    
    // MARK: - Private Methods
    
    private func setFeedTitle(text: String?) {
        if let title = text {
            self.feedTitleLabel.isHidden = false
            self.feedTitleLabel.attributedText = NSAttributedString.create(withText: title,
                                                                           fontStyle: .header2,
                                                                           colorType: .secondaryText)
        } else {
            self.feedTitleLabel.isHidden = true
        }
    }
    
    private func setFeedDescription(text: String?) {
        if let body = text {
            self.feedDescriptionLabel.isHidden = false
            self.feedDescriptionLabel.attributedText = NSAttributedString.create(withText: body,
                                                                                 fontStyle: .paragraph,
                                                                                 colorType: .secondaryText)
        } else {
            self.feedDescriptionLabel.isHidden = true
        }
    }
    
    private func setFeedImage(image: UIImage?) {
        if let image = image {
            self.feedImageView.isHidden = false
            self.feedImageView.image = image
        } else {
            self.feedImageView.isHidden = true
        }
    }
}
