//
//  DoubleButtonHorizontalView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 18/06/2020.
//

import Foundation

enum DoubleButtonHorizontalStyleCategory: StyleCategory {
    case secondaryBackground(firstButtonPrimary: Bool, secondButtonPrimary: Bool)
    
    var style: Style<DoubleButtonHorizontalView> {
        switch self {
        case .secondaryBackground(let firstButtonPrimary, let secondButtonPrimary):
            
            let buttonHeight: CGFloat = 46.0
            
            return Style<DoubleButtonHorizontalView> { buttonView in
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

class DoubleButtonHorizontalView: UIView {
    
    fileprivate var firstButtonAttributedTextStyle: AttributedTextStyle?
    fileprivate var secondButtonAttributedTextStyle: AttributedTextStyle?
    
    fileprivate let firstButton = UIButton()
    fileprivate let secondButton = UIButton()
    
    init(styleCategory: DoubleButtonHorizontalStyleCategory,
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
    
    public func setFirstButtonText(_ text: String) {
        guard let attributedTextStyle = self.firstButtonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.firstButton.setAttributedTitle(attributedText, for: .normal)
    }
    
    public func setSecondButtonText(_ text: String) {
        guard let attributedTextStyle = self.secondButtonAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.secondButton.setAttributedTitle(attributedText, for: .normal)
    }
}
