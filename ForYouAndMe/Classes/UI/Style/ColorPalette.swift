//
//  ColorPalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import SVProgressHUD

typealias ColorMap = [ColorType: UIColor]

enum ColorType: String, CaseIterable, CodingKey {
    case primary = "primary_color_start"
    case secondary = "secondary_color"
    case tertiary = "tertiary_color_start"
    case primaryText = "primary_text_color"
    case secondaryText = "secondary_text_color"
    case tertiaryText = "tertiary_text_color"
    case fourthText = "fourth_text_color"
    case primaryMenu = "primary_menu_color"
    case secondaryMenu = "secondary_menu_color"
    case active = "active_color"
    case inactive = "deactive_color"
    case gradientPrimaryEnd = "primary_color_end"
    case gradientTertiaryEnd = "tertiary_color_end"
    
    var defaultColor: UIColor {
        switch self {
        case .primary: return UIColor(hexRGB: 0x140F26)
        case .secondary: return UIColor(hexRGB: 0xFFFFFF)
        case .tertiary: return UIColor(hexRGB: 0x34CBD9)
        case .primaryText: return UIColor(hexRGB: 0x303740)
        case .secondaryText: return UIColor(hexRGB: 0xFFFFFF)
        case .tertiaryText: return UIColor(hexRGB: 0x25AEC2)
        case .fourthText: return UIColor(hexRGB: 0x828B93)
        case .primaryMenu: return UIColor(hexRGB: 0x140F26)
        case .secondaryMenu: return UIColor(hexRGB: 0xC4C4C4)
        case .active: return UIColor(hexRGB: 0x54C788)
        case .inactive: return UIColor(hexRGB: 0xDFDFDF)
        case .gradientPrimaryEnd: return UIColor(hexRGB: 0x0B99AE)
        case .gradientTertiaryEnd: return UIColor(hexRGB: 0x25B8C9)
        }
    }
}

class ColorPalette {
    
    private static var colorMap: ColorMap = [:]
    
    static func initialize(withColorMap colorMap: ColorMap) {
        self.colorMap = colorMap
        SVProgressHUD.setForegroundColor(ColorPalette.color(withType: .primary))
    }
    
    static func color(withType type: ColorType) -> UIColor {
        return self.colorMap[type] ?? type.defaultColor
    }
    
    // Fixed colors
    static var shadowColor = UIColor(hexRGB: 0x30374029)
}
