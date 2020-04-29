//
//  ColorPalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//

import UIKit

typealias ColorMap = [ColorType: UIColor]

enum ColorType: CaseIterable {
    case primary
    case secondary
    case tertiary
    case primaryText
    case secondaryText
    case tertiaryText
    case fourthText
    case primaryMenu
    case secondaryMenu
    case enabled
    case disabled
    case gradientPrimaryEnd
    case gradientSecondaryEnd
    
    var defaultColor: UIColor {
        switch self {
        case .primary: return UIColor(hexRGB: 0x25AEC2)
        case .secondary: return UIColor(hexRGB: 0xFFFFFF)
        case .tertiary: return UIColor(hexRGB: 0x34CBD9)
        case .primaryText: return UIColor(hexRGB: 0x303740)
        case .secondaryText: return UIColor(hexRGB: 0xFFFFFF)
        case .tertiaryText: return UIColor(hexRGB: 0x25AEC2)
        case .fourthText: return UIColor(hexRGB: 0x828B93)
        case .primaryMenu: return UIColor(hexRGB: 0x140F26)
        case .secondaryMenu: return UIColor(hexRGB: 0xC4C4C4)
        case .enabled: return UIColor(hexRGB: 0x54C788)
        case .disabled: return UIColor(hexRGB: 0xDFDFDF)
        case .gradientPrimaryEnd: return UIColor(hexRGB: 0x0B99AE)
        case .gradientSecondaryEnd: return UIColor(hexRGB: 0x25B8C9)
        }
    }
}

class ColorPalette {
    
    private static var colorMap: ColorMap = [:]
    
    static func initialize(withColorMap colorMap: ColorMap) {
        self.colorMap = colorMap
    }
    
    static func color(withType type: ColorType) -> UIColor? {
        return self.colorMap[type] ?? type.defaultColor
    }
}
