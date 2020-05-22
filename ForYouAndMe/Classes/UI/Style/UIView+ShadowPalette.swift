//
//  UIView+ShadowPalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

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
}
