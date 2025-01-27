//
//  TripleButtonHorizontalView.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 27/01/25.
//

import Foundation

enum TripleButtonHorizontalStyleCategory: StyleCategory {
    case primaryBackground(firstButtonPrimary: Bool, secondButtonPrimary: Bool)
    case secondaryBackground(firstButtonPrimary: Bool, secondButtonPrimary: Bool)
    
    var style: Style<TripleButtonHorizontalView> {
        switch self {
            
        case .primaryBackground(let firstButtonPrimary, let secondButtonPrimary):
            let buttonHeight: CGFloat = 46.0
            return Style<TripleButtonHorizontalView> { buttonView in
                
                buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
                
                let primaryTextAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .gradientPrimaryEnd)
                let secondaryTextAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .secondaryText)
                
                buttonView.firstButtonAttributedTextStyle =
                    firstButtonPrimary
                    ? secondaryTextAttributedTextStyle
                    : primaryTextAttributedTextStyle
                
                buttonView.firstButton.apply(style:
                    firstButtonPrimary
                        ? ButtonTextStyleCategory.primaryBackground(customHeight: buttonHeight).style
                        : ButtonTextStyleCategory.secondaryBackground(customHeight: buttonHeight).style)
                
                buttonView.secondButtonAttributedTextStyle =
                    secondButtonPrimary
                    ? secondaryTextAttributedTextStyle
                    : primaryTextAttributedTextStyle
                
                buttonView.secondButton.apply(style:
                    secondButtonPrimary
                        ? ButtonTextStyleCategory.primaryBackground(customHeight: buttonHeight).style
                        : ButtonTextStyleCategory.secondaryBackground(customHeight: buttonHeight).style)
                
                buttonView.thirdButtonAttributedTextStyle =
                    secondButtonPrimary
                    ? secondaryTextAttributedTextStyle
                    : primaryTextAttributedTextStyle
                
                buttonView.thirdButton.apply(style:
                    secondButtonPrimary
                        ? ButtonTextStyleCategory.primaryBackground(customHeight: buttonHeight).style
                        : ButtonTextStyleCategory.secondaryBackground(customHeight: buttonHeight).style)
                
                buttonView.addShadowLinear(goingDown: false)
            }
            
        case .secondaryBackground(let firstButtonPrimary, let secondButtonPrimary):
            
            let buttonHeight: CGFloat = 46.0
            
            return Style<TripleButtonHorizontalView> { buttonView in
                buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
                
                let primaryTextAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .gradientPrimaryEnd)
                let secondaryTextAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .secondaryText)
                
                buttonView.firstButtonAttributedTextStyle =
                    firstButtonPrimary
                    ? secondaryTextAttributedTextStyle
                    : primaryTextAttributedTextStyle
                buttonView.firstButton.apply(style:
                    firstButtonPrimary
                        ? ButtonTextStyleCategory.primaryBackground(customHeight: buttonHeight).style
                        : ButtonTextStyleCategory.secondaryBackground(customHeight: buttonHeight).style)
                
                buttonView.secondButtonAttributedTextStyle =
                    secondButtonPrimary
                    ? secondaryTextAttributedTextStyle
                    : primaryTextAttributedTextStyle
                buttonView.secondButton.apply(style:
                    secondButtonPrimary
                        ? ButtonTextStyleCategory.primaryBackground(customHeight: buttonHeight).style
                        : ButtonTextStyleCategory.secondaryBackground(customHeight: buttonHeight).style)
                
                buttonView.addShadowLinear(goingDown: false)
            }
        }
    }
}

class TripleButtonHorizontalView: UIView {
    
    fileprivate var firstButtonAttributedTextStyle: AttributedTextStyle?
    fileprivate var secondButtonAttributedTextStyle: AttributedTextStyle?
    fileprivate var thirdButtonAttributedTextStyle: AttributedTextStyle?
    
    fileprivate let firstButton = UIButton()
    fileprivate let secondButton = UIButton()
    fileprivate let thirdButton = UIButton()
    
    init(styleCategory: TripleButtonHorizontalStyleCategory,
         horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
         height: CGFloat = Constants.Style.DefaultFooterHeight) {
        super.init(frame: .zero)
        
        self.autoSetDimension(.height, toSize: height)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        self.addSubview(stackView)
        stackView.spacing = horizontalInset
        
        stackView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: horizontalInset)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: horizontalInset)
        stackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        let firstButtonContainerView = UIView()
        firstButtonContainerView.addSubview(self.firstButton)
        self.firstButton.autoPinEdgesToSuperviewEdges()
        stackView.addArrangedSubview(firstButtonContainerView)
        
        let secondButtonContainerView = UIView()
        secondButtonContainerView.addSubview(self.secondButton)
        self.secondButton.autoPinEdgesToSuperviewEdges()
        stackView.addArrangedSubview(secondButtonContainerView)
        
        let thirdButtonContainerView = UIView()
        thirdButtonContainerView.addSubview(self.thirdButton)
        self.thirdButton.tintColor = .white
        self.thirdButton.autoPinEdgesToSuperviewEdges()
        stackView.addArrangedSubview(thirdButtonContainerView)
        
        self.apply(style: styleCategory.style)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func addTargetToFirstButton(target: Any?, action: Selector) {
        self.firstButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    public func addTargetToSecondButton(target: Any?, action: Selector) {
        self.secondButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    public func addTargetToThirdButton(target: Any?, action: Selector) {
        self.thirdButton.addTarget(target, action: action, for: .touchUpInside)
    }
    
    public func setFirstButtonText(_ text: String) {
        guard let attributedTextStyle = self.firstButtonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.firstButton.setAttributedTitle(attributedText, for: .normal)
        self.firstButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    public func setSecondButtonText(_ text: String) {
        guard let attributedTextStyle = self.secondButtonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.secondButton.setAttributedTitle(attributedText, for: .normal)
        self.secondButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    public func setThirdButtonText(_ text: String) {
        guard let attributedTextStyle = self.secondButtonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.thirdButton.setAttributedTitle(attributedText, for: .normal)
        self.thirdButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    public func setFirstButtonImage(_ image: UIImage?) {
        self.firstButton.setImage(image, for: .normal)
        self.firstButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
        
    public func setSecondButtonImage(_ image: UIImage?) {
        self.secondButton.setImage(image, for: .normal)
        self.secondButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    public func setThirdButtonImage(_ image: UIImage?) {
        self.thirdButton.setImage(image, for: .normal)
        self.thirdButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    public func setThirdButtonColor(_ color: UIColor) {
        self.thirdButton.tintColor = color
    }
}
