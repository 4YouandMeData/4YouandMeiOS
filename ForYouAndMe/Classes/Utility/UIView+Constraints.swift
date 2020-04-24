//
//  UIView+Constraints.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

public extension UIView {
    func setHeight(_ height: CGFloat) {
        if let heightContraint = self.constraints.first(where: { $0.firstAttribute == .height }) {
            heightContraint.constant = height
        } else {
            self.autoSetDimension(.height, toSize: height)
        }
    }
    
    func setWidth(_ width: CGFloat) {
        if let widthContraint = self.constraints.first(where: { $0.firstAttribute == .width }) {
            widthContraint.constant = width
        } else {
            self.autoSetDimension(.width, toSize: width)
        }
    }
}
