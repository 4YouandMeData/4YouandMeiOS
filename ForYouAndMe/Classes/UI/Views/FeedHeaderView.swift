//
//  FeedHeaderView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/09/2020.
//

import UIKit

class FeedHeaderView: UIView {
    
    private static let buttonWidth: CGFloat = 50.0
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
    
    private let repository: Repository
    
    init(profileButtonPressed: @escaping NotificationCallback) {
        self.profileButtonPressed = profileButtonPressed
        self.repository = Services.shared.repository
        super.init(frame: .zero)
        
        self.autoSetDimension(.height, toSize: Self.height)
        
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView.create(withAxis: .horizontal, spacing: 16.0)
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 24.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 24.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
        
        let textStackView = UIStackView.create(withAxis: .vertical, spacing: 10.0)
        textStackView.addArrangedSubview(self.titleLabel)
        textStackView.addArrangedSubview(self.subtitleLabel)
        
        stackView.alignment = .center
        
        stackView.addArrangedSubview(self.profileButton)
        stackView.addArrangedSubview(textStackView)
        let emptySpaceView = UIView()
        emptySpaceView.autoSetDimension(.width, toSize: Self.buttonWidth)
        stackView.addArrangedSubview(emptySpaceView)
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
    
    // MARK: - Actions
    
    @objc private func onProfileButtonPressed() {
        self.profileButtonPressed()
    }
}
