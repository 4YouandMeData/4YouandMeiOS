//
//  DoubleButtonVerticalView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import UIKit
import PureLayout

enum DoubleButtonVerticalStyleCategory: StyleCategory {
    case secondaryBackground(backButton: Bool)
    
    var style: Style<DoubleButtonVerticalView> {
        switch self {
        case .secondaryBackground(let backButton): return Style<DoubleButtonVerticalView> { buttonView in
            buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
            if backButton {
                buttonView.primaryButton.setImage(ImagePalette.image(withName: .backButtonPrimary), for: .normal)
            } else {
                buttonView.primaryButton.setImage(ImagePalette.image(withName: .nextButtonPrimary), for: .normal)
            }
            buttonView.secondaryButtonAttributedTextStyle = AttributedTextStyle(fontStyle: .paragraph,
                                                                                colorType: .fourthText,
                                                                                textAlignment: .center,
                                                                                underlined: true)
            buttonView.addShadowLinear(goingDown: false)
            }
        }
    }
}

class DoubleButtonVerticalView: UIView {
    
    fileprivate var primaryButtonAttributedTextStyle: AttributedTextStyle?
    fileprivate var secondaryButtonAttributedTextStyle: AttributedTextStyle?
    
    fileprivate let primaryButton = UIButton()
    fileprivate let secondaryButton = UIButton()
    
    init(styleCategory: DoubleButtonVerticalStyleCategory,
         horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
         height: CGFloat = Constants.Style.DefaultFooterHeight) {
        super.init(frame: .zero)
        
        self.autoSetDimension(.height, toSize: height)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.spacing = 6.0
        
        stackView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .leading)
        stackView.autoPinEdge(toSuperviewEdge: .trailing)
        stackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        let secondaryButtonContainerView = UIView()
        secondaryButtonContainerView.addSubview(self.secondaryButton)
        self.secondaryButton.autoPinEdge(toSuperviewEdge: .top)
        self.secondaryButton.autoPinEdge(toSuperviewEdge: .bottom)
        self.secondaryButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 0.0, relation: .greaterThanOrEqual)
        self.secondaryButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0.0, relation: .greaterThanOrEqual)
        self.secondaryButton.autoAlignAxis(toSuperviewAxis: .vertical)
        stackView.addArrangedSubview(secondaryButtonContainerView)
        
        let primaryButtonContainerView = UIView()
        primaryButtonContainerView.addSubview(self.primaryButton)
        self.primaryButton.autoPinEdge(toSuperviewEdge: .top)
        self.primaryButton.autoPinEdge(toSuperviewEdge: .bottom)
        self.primaryButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 0.0, relation: .greaterThanOrEqual)
        self.primaryButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0.0, relation: .greaterThanOrEqual)
        self.primaryButton.autoAlignAxis(toSuperviewAxis: .vertical)
        stackView.addArrangedSubview(primaryButtonContainerView)
        
        self.apply(style: styleCategory.style)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func addTargetToPrimaryButton(target: Any?, action: Selector) {
        self.primaryButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    public func addTargetToSecondaryButton(target: Any?, action: Selector) {
        self.secondaryButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    public func setPrimaryButtonText(_ text: String) {
        guard let attributedTextStyle = self.primaryButtonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.primaryButton.setAttributedTitle(attributedText, for: .normal)
    }
    
    public func setSecondaryButtonText(_ text: String) {
        guard let attributedTextStyle = self.secondaryButtonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.secondaryButton.setAttributedTitle(attributedText, for: .normal)
    }
}
