//
//  UIView+Shadow.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

public extension UIView {
    func addShadowLinear(goingDown: Bool) {
        self.addShadow(shadowColor: ColorPalette.shadowColor,
                       shadowOffset: CGSize(width: 0.0, height: goingDown ? 4.0 : -4.0),
                       shadowOpacity: 0.1,
                       shadowRadius: 1.0)
    }
    
    func addShadowButton() {
        self.addShadow(shadowColor: ColorPalette.shadowColor,
                       shadowOffset: CGSize(width: 0.0, height: 4.0),
                       shadowOpacity: 0.1,
                       shadowRadius: 1.0)
    }
    
    func addShadow(shadowColor: UIColor, shadowOffset: CGSize, shadowOpacity: Float, shadowRadius: CGFloat) {
        self.layer.shadowColor = shadowColor.cgColor
        self.layer.shadowOffset = shadowOffset
        self.layer.shadowOpacity = shadowOpacity
        self.layer.shadowRadius = shadowRadius
        self.layer.masksToBounds = false
    }
    
    func clearShadow() {
        self.layer.shadowColor = nil
        self.layer.shadowOffset = CGSize.zero
        self.layer.shadowOpacity = 0
        self.layer.shadowRadius = 0
    }
}
