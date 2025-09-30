//
//  ColorPalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

//  ColorPalette.swift
//  ForYouAndMe
//
//  Dark Mode–ready

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
    
    /// Default (Light) palette
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
    
    /// Default (Dark) palette — sensata per partire; puoi affinarla con i tuoi brand colors.
    var defaultDarkColor: UIColor {
        switch self {
        case .primary: return UIColor(hexRGB: 0x0B0A14)          // darker background
        case .secondary: return UIColor(hexRGB: 0x1C1C1E)        // card bg
        case .tertiary: return UIColor(hexRGB: 0x34CBD9)         // keep accent
        case .fourth: return UIColor(hexRGB: 0x2C2C2E)           // elevated bg
        case .primaryText: return UIColor(hexRGB: 0xF2F2F7)      // primary label
        case .fabTextColor: return UIColor(hexRGB: 0x000000)     // black on light FAB
        case .secondaryText: return UIColor(hexRGB: 0xD1D1D6)    // secondary label
        case .tertiaryText: return UIColor(hexRGB: 0x34CBD9)     // accent text
        case .fourthText: return UIColor(hexRGB: 0x8E8E93)       // tertiary label
        case .primaryMenu: return UIColor(hexRGB: 0x0B0A14)
        case .secondaryMenu: return UIColor(hexRGB: 0x636366)
        case .active: return UIColor(hexRGB: 0x54C788)
        case .inactive: return UIColor(hexRGB: 0x3A3A3C)
        case .gradientPrimaryEnd: return UIColor(hexRGB: 0x0B99AE)
        case .gradientTertiaryEnd: return UIColor(hexRGB: 0x25B8C9)
        case .fabColorDefault: return UIColor(hexRGB: 0xFFFFFF)
        case .fabOutlineColor: return UIColor(hexRGB: 0x5A5A5A)
        case .secondaryBackgroungColor: return UIColor(hexRGB: 0x2C2C2E)
        case .reflectionColor: return UIColor(hexRGB: 0x5B4E2A)  // warmer dark bg
        case .reflectionTextColor: return UIColor(hexRGB: 0xFFD99B)
        case .noticedColor: return UIColor(hexRGB: 0x0A2540)     // dark blue bg
        case .noticedTextColor: return UIColor(hexRGB: 0x61A8FF)
        }
    }
}

final class ColorPalette {
    
    // MARK: - State
    
    private static var lightMap: ColorMap = [:]
    private static var darkMap: ColorMap = [:]
    
    // MARK: - Init
    
    /// Backward compatible initializer: same map used for both Light & Dark.
    static func initialize(withColorMap colorMap: ColorMap) {
        self.lightMap = colorMap
        self.darkMap = colorMap
        refreshThirdPartyAppearances(for: UITraitCollection.current)
    }
    
    /// New: provide distinct light/dark maps.
    static func initialize(light lightMap: ColorMap, dark darkMap: ColorMap? = nil) {
        self.lightMap = lightMap
        // If dark not provided, synthesize from defaults
        self.darkMap = darkMap ?? Self.synthesizedDark(from: lightMap)
        refreshThirdPartyAppearances(for: UITraitCollection.current)
    }
    
    // MARK: - Lookup
    
    /// Returns a dynamic UIColor that resolves based on the current UIUserInterfaceStyle.
    static func color(withType type: ColorType) -> UIColor {
        // Build a dynamic provider so the color auto-updates on theme change
        return UIColor { trait in
            let isDark = (trait.userInterfaceStyle == .dark)
            let map = isDark ? darkMap : lightMap
            // Prefer configured map; otherwise fall back to sensible defaults
            let configured = map[type]
            let fallback = isDark ? type.defaultDarkColor : type.defaultColor
            return configured ?? fallback
        }
    }
    
    // MARK: - Fixed Colors (now dynamic)
    
    /// Shadow adjusted for light/dark
    static var shadowColor: UIColor = UIColor { trait in
        // NOTE: keep alpha similar to original (0x29 ~ 16%) but tune base tone
        let base = (trait.userInterfaceStyle == .dark) ? UIColor.black : UIColor(hexRGB: 0x303740)
        return base.withAlphaComponent(0.16)
    }
    
    /// Overlay adjusted for light/dark
    static var overlayColor: UIColor = UIColor { trait in
        let base = (trait.userInterfaceStyle == .dark) ? UIColor.black : UIColor(hexRGB: 0x303740)
        return base.withAlphaComponent(0.5)
    }
    
    static var errorPrimaryColor: UIColor = UIColor { trait in
        return (trait.userInterfaceStyle == .dark) ? UIColor(hexRGB: 0xF2F2F7) : UIColor(hexRGB: 0x303740)
    }
    static var errorSecondaryColor: UIColor = UIColor { trait in
        return (trait.userInterfaceStyle == .dark) ? UIColor(hexRGB: 0x1C1C1E) : UIColor(hexRGB: 0xFFFFFF)
    }
    static var borderWarningColor: UIColor = UIColor { _ in UIColor(hexRGB: 0xFFCC00) }
    static var warningColor: UIColor = UIColor { trait in
        return (trait.userInterfaceStyle == .dark) ? UIColor(hexRGB: 0x3A2F1F) : UIColor(hexRGB: 0xFEF5EB)
    }
    
    // MARK: - Third-party refresh
    
    /// Call this when traits change to keep third-party components in sync (e.g., SVProgressHUD).
    static func refreshThirdPartyAppearances(for trait: UITraitCollection) {
        // SVProgressHUD doesn't auto-resolve dynamic colors; resolve explicitly.
        let primary = color(withType: .primary).resolvedColor(with: trait)
        SVProgressHUD.setForegroundColor(primary)
    }
    
    // MARK: - Helpers
    
    /// Creates a dark map by using configured light colors where present,
    /// otherwise using `defaultDarkColor`.
    private static func synthesizedDark(from light: ColorMap) -> ColorMap {
        var result: ColorMap = [:]
        for type in ColorType.allCases {
            // If a dark override is missing, prefer the same light color if it's already suitable,
            // otherwise fall back to default dark.
            let fallback = type.defaultDarkColor
            // Heuristic: if light color is very dark, reuse it.
            if let candidate = light[type], candidate.isVisuallyDark {
                result[type] = candidate
            } else {
                result[type] = fallback
            }
        }
        return result
    }
}

// MARK: - Small utilities

private extension UIColor {
    /// Very rough luminance check to decide if a color is "dark enough".
    /// Useful to synthesize a dark map from a light map without manual overrides.
    var isVisuallyDark: Bool {
        // Extract RGB in sRGB
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard self.getRed(&r, green: &g, blue: &b, alpha: &a) else { return false }
        // Relative luminance approximation
        let luminance = 0.2126*r + 0.7152*g + 0.0722*b
        return luminance < 0.35
    }
}
