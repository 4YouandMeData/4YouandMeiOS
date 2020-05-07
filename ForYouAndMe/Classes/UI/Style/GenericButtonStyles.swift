//
//  GenericButtonStyles.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

public class GenericButtonStyles {
    static let darkBackgroundStyle = Style<GenericButtonView> { buttonView in
        buttonView.backgroundColor = ColorPalette.color(withType: .primary)
        buttonView.addGradientView(.init(type: .defaultBackground))
        buttonView.button.apply(style: ButtonStyles.lightStyle)
        buttonView.addShadowLinear(goingDown: false)
    }
    
    static let lightBackgroundStyle = Style<GenericButtonView> { buttonView in
        buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
        buttonView.button.apply(style: ButtonStyles.darkStyle)
        buttonView.addShadowLinear(goingDown: false)
    }
}
