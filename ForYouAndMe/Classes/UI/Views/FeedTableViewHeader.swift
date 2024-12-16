//
//  FeedTableViewHeader.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/09/2020.
//

import UIKit

class FeedTableViewHeader: UIView {
    
    static let height: CGFloat = 110.0
    
    private let pointsLabel: UILabel = {
        let label = UILabel()
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private let repository: Repository
    
    // MARK: - AttributedTextStyles
    
    private let pointsLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                     colorType: .secondaryText,
                                                                     textAlignment: .center)
    
    init() {
        self.repository = Services.shared.repository
        super.init(frame: .zero)
        
        self.autoSetDimension(.height, toSize: Self.height)
        
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView.create(withAxis: .horizontal, spacing: 16.0)
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 24.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        
        let textStackView = UIStackView.create(withAxis: .vertical, spacing: 10.0)
        textStackView.addLabel(withText: StringsProvider.string(forKey: .tabFeedHeaderTitle),
                               fontStyle: .paragraph,
                               color: ColorPalette.color(withType: .secondaryText).applyAlpha(0.6),
                               textAlignment: .left)
        textStackView.addArrangedSubview(self.subtitleLabel)
        stackView.addArrangedSubview(textStackView)
        
        let descriptionText = StringsProvider.string(forKey: .tabFeedHeaderPoints)
        
        if !descriptionText.isEmpty {
            
            let pointsStackView = UIStackView.create(withAxis: .vertical, spacing: 2.0)
            pointsStackView.addArrangedSubview(self.pointsLabel)
            
            let pointsDescriptionLabel = UILabel()
            pointsDescriptionLabel.attributedText = NSAttributedString
                .create(withText: descriptionText,
                        fontStyle: .header3,
                        color: ColorPalette.color(withType: .secondaryText).applyAlpha(0.6))
            pointsStackView.addArrangedSubview(pointsDescriptionLabel)
            self.pointsLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            self.pointsLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            pointsDescriptionLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            pointsDescriptionLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            
            stackView.alignment = .center
            
            stackView.addArrangedSubview(pointsStackView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func setPoints(_ points: Int) {
        self.pointsLabel.attributedText = NSAttributedString.create(withText: "\(points)",
            attributedTextStyle: self.pointsLabelAttributedTextStyle)
    }
    
    public func refreshUI() {
        let text = StringsProvider.string(forKey: .tabFeedHeaderSubtitle, forPhaseIndex: self.repository.currentPhaseIndex)
        self.subtitleLabel.attributedText = NSAttributedString.create(withText: text,
                                                                      fontStyle: .title,
                                                                      colorType: .secondaryText,
                                                                      textAlignment: .left)
    }
}
