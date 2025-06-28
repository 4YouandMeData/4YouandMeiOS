//
//  FeedHeaderView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/09/2020.
//

import UIKit

class FeedHeaderView: UIView {
    
    private static let buttonWidth: CGFloat = 70.0
    private static let height: CGFloat = 150.0
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        return label
    }()
    
    private lazy var profileButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(self.onProfileButtonPressed), for: .touchUpInside)
        button.setImage(ImagePalette.image(withName: .mainLogo), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.autoSetDimension(.width, toSize: Self.buttonWidth)
        button.autoSetDimension(.height, toSize: Self.buttonWidth)
        return button
    }()
    
    private lazy var comingSoonButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.messages.style)
//        button.setTitle(MessageMap.getMessageContent(byKey: "feed")?.title, for: .normal)
        button.addTarget(self, action: #selector(self.onComingSoonButtonPressed), for: .touchUpInside)
        button.autoSetDimension(.width, toSize: 110)
        return button
    }()
    
    // MARK: - AttributedTextStyles
    
    private let titleLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .paragraph,
                                                                    colorType: .secondaryText,
                                                                    textAlignment: .center,
                                                                    alpha: 0.6)
    private let subtitleLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                       colorType: .secondaryText,
                                                                       textAlignment: .center)
    
    private let profileButtonPressed: NotificationCallback
    private let comingSoonButtonPressed: NotificationCallback
    
    private let repository: Repository
    
    init(profileButtonPressed: @escaping NotificationCallback,
         comingSoonButtonPressed: @escaping NotificationCallback) {
        self.profileButtonPressed = profileButtonPressed
        self.comingSoonButtonPressed = comingSoonButtonPressed
        self.repository = Services.shared.repository
        super.init(frame: .zero)
        
        self.autoSetDimension(.height, toSize: Self.height)
        
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView.create(withAxis: .horizontal, spacing: 16.0)
        self.addSubview(stackView)
        
        self.addSubview(self.profileButton)
        
        stackView.autoPinEdge(.leading, to: .trailing, of: self.profileButton, withOffset: 16.0)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        stackView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 24.0)
        
        self.profileButton.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        self.profileButton.autoPinEdge(toSuperviewSafeArea: .top, withInset: 12.0)
        self.profileButton.autoSetDimensions(to: CGSize(width: Self.buttonWidth, height: Self.buttonWidth))
        
        let textStackView = UIStackView.create(withAxis: .vertical, spacing: 10.0)
        textStackView.addArrangedSubview(self.titleLabel)
        textStackView.addArrangedSubview(self.subtitleLabel)
        
        stackView.alignment = .center
        
        stackView.addArrangedSubview(textStackView)
        
        stackView.addArrangedSubview(self.comingSoonButton)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func setTitleText(_ title: String) {
        self.titleLabel.attributedText = NSAttributedString.create(withText: title,
                                                                   attributedTextStyle: self.titleLabelAttributedTextStyle)
    }
    
    public func setSubtitleText(_ subtitle: String) {
        self.subtitleLabel.attributedText = NSAttributedString.create(withText: subtitle,
                                                                      attributedTextStyle: self.subtitleLabelAttributedTextStyle)
    }
    
    public func refreshUI() {
        self.profileButton.syncWithPhase(repository: self.repository, imageName: .mainLogo)
    }
    
    public func setComingSoonTitle(title: String) {
        self.comingSoonButton.setTitle(title, for: .normal)
    }
    
    public func showComingSoonButton(show: Bool) {
        self.comingSoonButton.isHidden = !show
    }
    
    // MARK: - Actions
    
    @objc private func onProfileButtonPressed() {
        self.profileButtonPressed()
    }
    
    @objc private func onComingSoonButtonPressed() {
        self.comingSoonButtonPressed()
    }
}
