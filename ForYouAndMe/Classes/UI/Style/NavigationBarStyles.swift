//
//  NavigationBarStyles.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

class NavigationBarStyles {
    static let hiddenStyle = Style<UINavigationBar> { bar in
        bar.isHidden = true
    }
    
    static let primaryStyle = Style<UINavigationBar> { bar in
        bar.isHidden = false
        bar.isTranslucent = false
        bar.addGradient(type: .primaryBackground)
        bar.tintColor = ColorPalette.color(withType: .secondary)
        bar.prefersLargeTitles = false
        bar.shadowImage = UIImage() // Remove Separator line
        bar.titleTextAttributes = [.foregroundColor: ColorPalette.color(withType: .secondaryText),
                                   .font: FontPalette.fontStyleData(forStyle: .paragraph).font]
    }
    
    static let secondaryStyle = Style<UINavigationBar> { bar in
        bar.isHidden = false
        bar.isTranslucent = false
        bar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        bar.barTintColor = ColorPalette.color(withType: .secondary)
        bar.tintColor = ColorPalette.color(withType: .primaryText)
        bar.prefersLargeTitles = false
        bar.shadowImage = UIImage() // Remove Separator line
        bar.titleTextAttributes = [.foregroundColor: ColorPalette.color(withType: .primaryText),
                                   .font: FontPalette.fontStyleData(forStyle: .paragraph).font]
    }
    
    static let activeStyle = Style<UINavigationBar> { bar in
        bar.isHidden = false
        bar.isTranslucent = false
        bar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        bar.barTintColor = ColorPalette.color(withType: .active)
        bar.tintColor = ColorPalette.color(withType: .secondary)
        bar.prefersLargeTitles = false
        bar.shadowImage = UIImage() // Remove Separator line
        bar.titleTextAttributes = [.foregroundColor: ColorPalette.color(withType: .secondaryText),
                                   .font: FontPalette.fontStyleData(forStyle: .paragraph).font]
    }
}

fileprivate extension UINavigationBar {
    func addGradient(type: GradientViewType) {
        let gradient = CAGradientLayer()
        var bounds = self.bounds
        bounds.size.height += UIApplication.shared.windows.first?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        gradient.frame = bounds
        gradient.colors = type.colors.map { $0.cgColor }
        gradient.startPoint = type.startPoint
        gradient.endPoint = type.endPoint

        if let image = self.getImageFrom(gradientLayer: gradient) {
            self.setBackgroundImage(image, for: UIBarMetrics.default)
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
