//
//  NavigationBarStyles.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

enum NavigationBarStyleCategory: StyleCategory {
    case primary(hidden: Bool)
    case secondary(hidden: Bool)
    case active(hidden: Bool)
    
    var style: Style<UINavigationBar> {
        switch self {
        case .primary(let hidden): return Style<UINavigationBar> { bar in
            bar.isHidden = hidden
            bar.isTranslucent = false
            bar.addGradient(type: .primaryBackground, removeShadow: true)
            bar.tintColor = ColorPalette.color(withType: .secondary)
            bar.prefersLargeTitles = false
            bar.titleTextAttributes = [.foregroundColor: ColorPalette.color(withType: .secondaryText),
                                       .font: FontPalette.fontStyleData(forStyle: .paragraph).font]
            Self.adaptStatusBar(forColor: ColorPalette.color(withType: .primary))
            }
        case .secondary(let hidden): return Style<UINavigationBar> { bar in
            bar.isHidden = hidden
            bar.isTranslucent = false
            bar.setBackgroundColor(ColorPalette.color(withType: .secondary), removeShadow: true)
            bar.tintColor = ColorPalette.color(withType: .primaryText)
            bar.prefersLargeTitles = false
            bar.titleTextAttributes = [.foregroundColor: ColorPalette.color(withType: .primaryText),
                                       .font: FontPalette.fontStyleData(forStyle: .paragraph).font]
            Self.adaptStatusBar(forColor: ColorPalette.color(withType: .secondary))
            }
        case .active(let hidden): return Style<UINavigationBar> { bar in
            bar.isHidden = hidden
            bar.isTranslucent = false
            bar.setBackgroundColor(ColorPalette.color(withType: .active), removeShadow: true)
            bar.tintColor = ColorPalette.color(withType: .secondary)
            bar.prefersLargeTitles = false
            bar.titleTextAttributes = [.foregroundColor: ColorPalette.color(withType: .secondaryText),
                                       .font: FontPalette.fontStyleData(forStyle: .paragraph).font]
            Self.adaptStatusBar(forColor: ColorPalette.color(withType: .active))
            }
        }
    }
    
    private static func adaptStatusBar(forColor color: UIColor) {
        guard let colorComponents = color.components else {
            assertionFailure("Couldn't retrieve color components")
            return
        }
        if (colorComponents.red * 255.0 * 0.299 + colorComponents.green * 255.0 * 0.587 + colorComponents.blue * 255.0 * 0.114) > 186 {
            UIApplication.shared.statusBarStyle = .darkContent
        } else {
            UIApplication.shared.statusBarStyle = .lightContent
        }
    }
}

fileprivate extension UINavigationBar {
    func setBackgroundColor(_ color: UIColor, removeShadow: Bool) {
        self.barTintColor = color
        self.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        
        if removeShadow {
            self.shadowImage = UIImage()
        }
        
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
            appearance.backgroundImage = UIImage()
            
            if removeShadow {
                appearance.shadowColor = .clear
            }
            
            self.standardAppearance = appearance
            self.scrollEdgeAppearance = appearance
        }
    }
    
    func addGradient(type: GradientViewType, removeShadow: Bool) {
        let gradient = CAGradientLayer()
        var bounds = self.bounds
        bounds.size.height += UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        gradient.frame = bounds
        gradient.colors = type.colors.map { $0.cgColor }
        gradient.startPoint = type.startPoint
        gradient.endPoint = type.endPoint
        
        if removeShadow {
            self.shadowImage = UIImage()
        }

        if let image = self.getImageFrom(gradientLayer: gradient) {
            self.setBackgroundImage(image, for: UIBarMetrics.default)
            if #available(iOS 15.0, *) {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundImage = image
                
                if removeShadow {
                    appearance.shadowColor = .clear
                }
                
                self.standardAppearance = appearance
                self.scrollEdgeAppearance = appearance
            }
        }
    }
    
    private func getImageFrom(gradientLayer: CAGradientLayer) -> UIImage? {
        var gradientImage: UIImage?
        UIGraphicsBeginImageContext(gradientLayer.frame.size)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
            gradientImage = UIGraphicsGetImageFromCurrentImageContext()?
                .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        }
        UIGraphicsEndImageContext()
        return gradientImage
    }
}
