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
    case secondaryBackgroungColor = "secondary_background_color"
    case tertiary = "tertiary_color_start"
    case fourth = "fourth_color"
    case primaryText = "primary_text_color"
    case secondaryText = "secondary_text_color"
    case tertiaryText = "tertiary_text_color"
    case fourthText = "fourth_text_color"
    case primaryMenu = "primary_menu_color"
    case secondaryMenu = "secondary_menu_color"
    case active = "active_color"
    case inactive = "deactive_color"
    case fabTextColor = "fab_text_color"
    case gradientPrimaryEnd = "primary_color_end"
    case gradientTertiaryEnd = "tertiary_color_end"
    case fabColorDefault = "fab_color_default"
    case fabOutlineColor = "fab_outline_color"
    case reflectionColor = "reflection_color"
    case reflectionTextColor = "reflection_text_color"
    case noticedColor = "noticed_color"
    case noticedTextColor = "noticed_text_color"
    
    var defaultColor: UIColor {
        switch self {
        case .primary: return UIColor(hexRGB: 0x140F26)
        case .secondary: return UIColor(hexRGB: 0xFFFFFF)
        case .tertiary: return UIColor(hexRGB: 0x34CBD9)
        case .fourth: return UIColor(hexRGB: 0xF5F5F5)
        case .primaryText: return UIColor(hexRGB: 0x303740)
        case .fabTextColor: return UIColor(hexRGB: 0xFFFFFF)
        case .secondaryText: return UIColor(hexRGB: 0xFFFFFF)
        case .tertiaryText: return UIColor(hexRGB: 0x25AEC2)
        case .fourthText: return UIColor(hexRGB: 0x828B93)
        case .primaryMenu: return UIColor(hexRGB: 0x140F26)
        case .secondaryMenu: return UIColor(hexRGB: 0xC4C4C4)
        case .active: return UIColor(hexRGB: 0x54C788)
        case .inactive: return UIColor(hexRGB: 0xDFDFDF)
        case .gradientPrimaryEnd: return UIColor(hexRGB: 0x0B99AE)
        case .gradientTertiaryEnd: return UIColor(hexRGB: 0x25B8C9)
        case .fabColorDefault: return UIColor(hexRGB: 0xFFFFFF)
        case .fabOutlineColor: return UIColor(hexRGB: 0xA5A5A5)
        case .secondaryBackgroungColor: return UIColor(hexRGB: 0xDFDFDF)
        case .reflectionColor: return UIColor(hexRGB: 0xFFE993)
        case .reflectionTextColor: return UIColor(hexRGB: 0x905006)
        case .noticedColor: return UIColor(hexRGB: 0xD4E8FF)
        case .noticedTextColor: return UIColor(hexRGB: 0x007AFF)
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
    static var shadowColor = UIColor(hexRGBA: 0x30374029)
    static var overlayColor = UIColor(hexRGBA: 0x30374080)
    
    static var errorPrimaryColor = UIColor(hexRGB: 0x303740)
    static var errorSecondaryColor = UIColor(hexRGB: 0xFFFFFF)
    static var borderWarningColor =  UIColor(hexRGB: 0xFFCC00)
    static var warningColor = UIColor(hexRGB: 0xFEF5EB)
}
