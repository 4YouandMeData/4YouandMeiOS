//
//  UIColor+Extension.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

public struct ColorComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

public extension UIColor {
    
    convenience init(red: UInt8, green: UInt8, blue: UInt8, alpha: Float = 1.0) {
        self.init(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: CGFloat(alpha)
        )
    }
    
    convenience init(withHexRed red: Int, green: Int, blue: Int) {
        self.init(withHexRed: red, green: green, blue: blue, alpha: 255)
    }
    
    convenience init(withHexRed red: Int, green: Int, blue: Int, alpha: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        assert(alpha >= 0 && alpha <= 255, "Invalid alpha component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: CGFloat(alpha) / 255.0)
    }
    
    convenience init(hexRGB: Int) {
        self.init(
            withHexRed: (hexRGB >> 16) & 0xFF,
            green: (hexRGB >> 8) & 0xFF,
            blue: hexRGB & 0xFF
        )
    }
    
    convenience init(hexRGBA: Int) {
        self.init(
            withHexRed: (hexRGBA >> 24) & 0xFF,
            green: (hexRGBA >> 16) & 0xFF,
            blue: (hexRGBA >> 8) & 0xFF,
            alpha: hexRGBA & 0xFF
        )
    }
    
    var clearColor: UIColor {
        if let components = self.components {
            return UIColor(red: components.red, green: components.green, blue: components.blue, alpha: 0.0)
        } else {
            return UIColor.clear
        }
    }
    
    var components: ColorComponents? {
        var fRed: CGFloat = 0
        var fGreen: CGFloat = 0
        var fBlue: CGFloat = 0
        var fAlpha: CGFloat = 0
        if self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha) {
            return ColorComponents(red: fRed, green: fGreen, blue: fBlue, alpha: fAlpha)
        } else {
            return nil
        }
    }
    
    func applyAlpha(_ alpha: CGFloat) -> UIColor {
        if let components = self.components {
            return UIColor(red: components.red, green: components.green, blue: components.blue, alpha: alpha)
        } else {
            return UIColor.clear
        }
    }
}
