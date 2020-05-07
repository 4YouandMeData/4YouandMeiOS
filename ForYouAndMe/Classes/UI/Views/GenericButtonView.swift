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
    
    init(withStyle style: Style<GenericButtonView>,
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
        self.apply(style: style)
        
        self.buttonEnabledObserver = self.button.observe(\UIButton.isEnabled, changeHandler: { button, _ in
            if button.isEnabled {
                self.button.backgroundColor = self.button.backgroundColor?.applyAlpha(1.0)
            } else {
                self.button.backgroundColor = self.button.backgroundColor?.applyAlpha(0.5)
            }
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
