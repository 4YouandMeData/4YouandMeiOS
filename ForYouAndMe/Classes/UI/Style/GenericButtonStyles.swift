//
//  GenericButtonStyles.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

enum GenericButtonTextStyleCategory: StyleCategory {
    case primaryBackground
    case secondaryBackground
    
    var style: Style<GenericButtonView> {
        switch self {
        case .primaryBackground: return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = ColorPalette.color(withType: .primary)
            buttonView.addGradientView(.init(type: .primaryBackground))
            buttonView.button.apply(style: ButtonTextStyleCategory.secondaryBackground(customHeight: nil).style)
            buttonView.addShadowLinear(goingDown: false)
            }
        case .secondaryBackground: return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
            buttonView.button.apply(style: ButtonTextStyleCategory.primaryBackground(customHeight: nil).style)
            buttonView.addShadowLinear(goingDown: false)
            }
        }
    }
}

enum GenericButtonImageStyleCategory: StyleCategory {
    case primaryBackground
    case secondaryBackground
    
    var style: Style<GenericButtonView> {
        switch self {
        case .primaryBackground: return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = ColorPalette.color(withType: .primary)
            buttonView.addGradientView(.init(type: .primaryBackground))
            buttonView.button.setImage(ImagePalette.image(withName: .nextButtonSecondary), for: .normal)
            buttonView.addShadowLinear(goingDown: false)
            }
        case .secondaryBackground: return Style<GenericButtonView> { buttonView in
            buttonView.backgroundColor = ColorPalette.color(withType: .secondary)
            buttonView.button.setImage(ImagePalette.image(withName: .nextButtonPrimary), for: .normal)
            buttonView.addShadowLinear(goingDown: false)
            }
        }
    }
}
