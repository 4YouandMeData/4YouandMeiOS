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
    static let darkStyle = Style<GenericButtonView> { buttonView in
        buttonView.backgroundColor = ColorPalette.color(withType: .primary)
        buttonView.button.apply(style: ButtonStyles.lightStyle)
        buttonView.addShadowLinear(goingDown: false)
    }
    
    static let lightStyle = Style<GenericButtonView> { buttonView in
        buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
        buttonView.button.apply(style: ButtonStyles.darkStyle)
        buttonView.addShadowLinear(goingDown: false)
    }
}
