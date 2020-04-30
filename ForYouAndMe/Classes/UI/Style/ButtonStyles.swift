//
//  ButtonStyles.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

public class ButtonStyles {
    
    private static let defaultHeight: CGFloat = 52.0
    private static let defaultCornerRadius: CGFloat = defaultHeight / 2.0
    
    static let darkStyle = Style<UIButton> { button in
        button.autoSetDimension(.height, toSize: defaultHeight)
        button.layer.cornerRadius = defaultCornerRadius
        button.backgroundColor = ColorPalette.color(withType: .primary)
        button.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
        button.titleLabel?.font = FontPalette.font(withSize: 20.0)
    }
    
    static let lightStyle = Style<UIButton> { button in
        button.autoSetDimension(.height, toSize: defaultHeight)
        button.layer.cornerRadius = defaultCornerRadius
        button.backgroundColor = ColorPalette.color(withType: .secondary)
        button.setTitleColor(ColorPalette.color(withType: .tertiaryText), for: .normal)
        button.titleLabel?.font = FontPalette.font(withSize: 20.0)
    }
}
