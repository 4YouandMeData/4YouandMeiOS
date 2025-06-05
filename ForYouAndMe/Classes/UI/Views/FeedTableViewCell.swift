//
//  FeedTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit

class FeedTableViewCell: UITableViewCell {
    
    private static let imageHeight: CGFloat = 56.0
    
    private let gradientView: GradientView = {
        return GradientView(colors: [UIColor.white, UIColor.white],
                            locations: [0.0, 1.0],
                            startPoint: CGPoint(x: 0.5, y: 0.0),
                            endPoint: CGPoint(x: 0.5, y: 1.0))
    }()
    
    private lazy var feedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.height, toSize: Self.imageHeight)
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
        let button = GenericButtonView(withTextStyleCategory: .feed,
                                       fillWidth: true,
                                       horizontalInset: 8.0,
                                       topInset: 30.0,
                                       bottomInset: 0.0)
        button.addTarget(target: self, action: #selector(self.buttonPressed))
        
        return button
    }()
    
    private lazy var skipButtonView: GenericButtonView = {
        let button = GenericButtonView(withTextStyleCategory: .feed,
                                       fillWidth: true,
                                       horizontalInset: 8.0,
                                       topInset: 30.0,
                                       bottomInset: 0.0)
        button.addTarget(target: self, action: #selector(self.skipButtonPressed))
        return button
    }()
    
    private lazy var horizontalStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8.0
        stack.alignment = .center
        stack.addArrangedSubview(self.buttonView)
        return stack
    }()
    
    private var buttonPressedCallback: NotificationCallback?
    private var skipButtonPressedCallback: NotificationCallback?
    
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
        self.gradientView.setContentHuggingPriority(UILayoutPriority(100), for: .vertical)
        self.gradientView.setContentCompressionResistancePriority(UILayoutPriority(100), for: .vertical)
        panelView.backgroundColor = ColorPalette.color(withType: .primary)
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
        
        self.horizontalStackView.axis = .horizontal
        self.horizontalStackView.distribution = .fillEqually
        stackView.addArrangedSubview(horizontalStackView)
        self.horizontalStackView.addArrangedSubview(self.buttonView)
        self.horizontalStackView.addArrangedSubview(self.skipButtonView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: Activity,
                        skippable: Bool = false,
                        buttonPressedCallback: @escaping NotificationCallback,
                        skipButtonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        self.skipButtonPressedCallback = skipButtonPressedCallback
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        if nil != data.taskType {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .activityButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
            
            self.horizontalStackView.distribution = .fill

            if skippable {
                
                if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) == false {
                    self.horizontalStackView.addArrangedSubview(self.skipButtonView)
                }
                let skipText = StringsProvider.string(forKey: .skipActivityButtonDefault)
                self.skipButtonView.isHidden = false
                self.skipButtonView.setButtonText(skipText)
                
                self.horizontalStackView.distribution = .fillEqually
                
            } else {
                
                if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) {
                    self.horizontalStackView.removeArrangedSubview(self.skipButtonView)
                    self.skipButtonView.removeFromSuperview()
                }
                
                self.horizontalStackView.distribution = .fill
            }
            
            self.horizontalStackView.isHidden = false
            
        } else {
            assert(data.buttonText == nil, "Existing button text for activity without activity type")
            self.buttonView.isHidden = true
        }
    }
    
    public func display(data: Survey,
                        skippable: Bool,
                        buttonPressedCallback: @escaping NotificationCallback,
                        skipButtonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        self.skipButtonPressedCallback = skipButtonPressedCallback
        
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        let buttonText = data.buttonText ?? StringsProvider.string(forKey: .surveyButtonDefault)
        self.buttonView.isHidden = false
        self.buttonView.setButtonText(buttonText)
        
        self.horizontalStackView.distribution = .fill
        
        if skippable {
            
            if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) == false {
                self.horizontalStackView.addArrangedSubview(self.skipButtonView)
            }
            let skipText = StringsProvider.string(forKey: .skipActivityButtonDefault)
            self.skipButtonView.isHidden = false
            self.skipButtonView.setButtonText(skipText)
            
            self.horizontalStackView.distribution = .fillEqually
            
        } else {
            
            if self.horizontalStackView.arrangedSubviews.contains(self.skipButtonView) {
                self.horizontalStackView.removeArrangedSubview(self.skipButtonView)
                self.skipButtonView.removeFromSuperview()
            }
            
            self.horizontalStackView.distribution = .fill
        }
        
        self.horizontalStackView.isHidden = false
    }
    
    public func display(data: Educational, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        if nil != data.urlString {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .educationalButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            assert(data.buttonText == nil, "Existing button text for notifiable without urlString")
            self.buttonView.isHidden = true
        }
    }
    
    public func display(data: Alert, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        if nil != data.urlString {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .alertButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            assert(data.buttonText == nil, "Existing button text for notifiable without urlString")
            self.buttonView.isHidden = true
        }
    }
    
    public func display(data: Reward, buttonPressedCallback: @escaping NotificationCallback) {
        self.buttonPressedCallback = buttonPressedCallback
        
        self.updateGradientView(startColor: data.startColor, endColor: data.endColor, singleColor: data.cardColor)
        self.setFeedImage(imageUrl: data.image)
        self.setFeedTitle(text: data.title)
        self.setFeedDescription(text: data.body)
        
        if nil != data.urlString {
            let buttonText = data.buttonText ?? StringsProvider.string(forKey: .rewardButtonDefault)
            self.buttonView.isHidden = false
            self.buttonView.setButtonText(buttonText)
        } else {
            assert(data.buttonText == nil, "Existing button text for notifiable without urlString")
            self.buttonView.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.buttonPressedCallback?()
    }
    
    @objc private func skipButtonPressed() {
        self.skipButtonPressedCallback?()
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
    
    private func setFeedImage(imageUrl: URL?) {
        if let imageUrl = imageUrl {
            self.feedImageView.isHidden = false
            self.feedImageView.loadAsyncImage(withURL: imageUrl,
                                              placeHolderImage: Constants.Resources.AsyncImagePlaceholder,
                                              targetSize: CGSize(width: UIScreen.main.bounds.width, height: Self.imageHeight))
        } else {
            self.feedImageView.isHidden = true
        }
    }
    
    private func updateGradientView(startColor: UIColor?, endColor: UIColor?, singleColor: UIColor?) {
        if let startColor = startColor, let endColor = endColor {
            self.gradientView.updateParameters(colors: [startColor, endColor])
        } else {
            self.gradientView.updateParameters(colors: [singleColor ?? ColorPalette.color(withType: .primary),
                                                        singleColor ?? ColorPalette.color(withType: .gradientPrimaryEnd)])
        }
    }
}
