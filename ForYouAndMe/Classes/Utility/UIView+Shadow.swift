//
//  UIView+Shadow.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

public extension UIView {
    func addShadowButton() {
        self.addShadow(shadowColor: UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 0.3),
                       shadowOffset: CGSize(width: 0.0, height: 2.0),
                       shadowOpacity: 1.0,
                       shadowRadius: 8.0)
    }
    
    func addShadowLinear(goingDown: Bool) {
        self.addShadow(shadowColor: UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.6),
                       shadowOffset: CGSize(width: 0.0, height: goingDown ? 2.0 : -2.0),
                       shadowOpacity: 1.0,
                       shadowRadius: 1.0)
    }
    
    func addShadowCard() {
        self.addShadow(shadowColor: UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 0.3),
                       shadowOffset: CGSize(width: 0.0, height: 2.0),
                       shadowOpacity: 1.0,
                       shadowRadius: 8.0)
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
