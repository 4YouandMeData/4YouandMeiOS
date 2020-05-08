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
    var heightConstraint: CGFloat? {
        get {
            return self.constraints.first(where: { $0.firstAttribute == .height })?.constant
        }
        set {
            if let heightContraint = self.constraints.first(where: { $0.firstAttribute == .height }) {
                if let height = newValue {
                    heightContraint.constant = height
                } else {
                    heightContraint.autoRemove()
                }
            } else {
                if let height = newValue {
                    self.autoSetDimension(.height, toSize: height)
                }
            }
        }
    }
    var widthConstraint: CGFloat? {
        get {
            return self.constraints.first(where: { $0.firstAttribute == .width })?.constant
        }
        set {
            if let widthContraint = self.constraints.first(where: { $0.firstAttribute == .width }) {
                if let width = newValue {
                    widthContraint.constant = width
                } else {
                    widthContraint.autoRemove()
                }
            } else {
                if let width = newValue {
                    self.autoSetDimension(.width, toSize: width)
                }
            }
        }
    }
}
