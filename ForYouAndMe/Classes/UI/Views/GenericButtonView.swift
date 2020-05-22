//
//  GenericButtonView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

class GenericButtonView: UIView {
    
    public let button = UIButton()
    
    private var buttonEnabledObserver: NSKeyValueObservation?
    
    init(withTextStyleCategory textStyleCategory: GenericButtonTextStyleCategory,
         fillWidth: Bool = true,
         horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
         topInset: CGFloat = 32.0,
         bottomInset: CGFloat = 32.0) {
        super.init(frame: .zero)
        
        self.addSubview(self.button)
        self.button.autoPinEdge(toSuperviewEdge: .top, withInset: topInset)
        self.button.autoPinEdge(toSuperviewEdge: .bottom, withInset: bottomInset)
        self.button.autoPinEdge(toSuperviewEdge: .leading, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .trailing, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoAlignAxis(toSuperviewAxis: .vertical)
        self.apply(style: textStyleCategory.style)
        
        self.sharedSetup()
    }
    
    convenience init(withTextStyleCategory textStyleCategory: GenericButtonTextStyleCategory,
                     fillWidth: Bool = true,
                     horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
                     height: CGFloat = Constants.Style.DefaultFooterButtonHeight) {
        self.init(withStyle: textStyleCategory.style, fillWidth: fillWidth, horizontalInset: horizontalInset, height: height)
    }
    
    convenience init(withImageStyleCategory imageStyleCategory: GenericButtonImageStyleCategory,
                     height: CGFloat = Constants.Style.DefaultFooterButtonHeight) {
        self.init(withStyle: imageStyleCategory.style, fillWidth: false, height: height)
    }
    
    private init(withStyle style: Style<GenericButtonView>,
                 fillWidth: Bool = true,
                 horizontalInset: CGFloat = Constants.Style.DefaultHorizontalMargins,
                 height: CGFloat) {
        super.init(frame: .zero)
        
        self.addSubview(self.button)
        if let buttonHeight = self.button.heightConstraint, buttonHeight > height {
            self.autoSetDimension(.height, toSize: buttonHeight)
        } else {
            self.autoSetDimension(.height, toSize: height)
        }
        self.button.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .leading, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .trailing, withInset: horizontalInset, relation: fillWidth ? .equal : .greaterThanOrEqual)
        self.button.autoCenterInSuperview()
        self.apply(style: style)
        
        self.sharedSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private Methods
    
    private func sharedSetup() {
        self.buttonEnabledObserver = self.button.observe(\UIButton.isEnabled, changeHandler: { button, _ in
            if button.isEnabled {
                self.button.backgroundColor = self.button.backgroundColor?.applyAlpha(1.0)
            } else {
                self.button.backgroundColor = self.button.backgroundColor?.applyAlpha(0.5)
            }
        })
    }
}
