//
//  ButtonStyles.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

enum ButtonTextStyleCategory: StyleCategory {
    case primaryBackground(customHeight: CGFloat?)
    case secondaryBackground(customHeight: CGFloat?)
    case loadingErrorStyle
    case feed
    
    var style: Style<UIButton> {
        switch self {
        case .primaryBackground(let customHeight): return Style<UIButton> { button in
            let buttonHeight = self.buttonHeight(fromCustomHeight: customHeight)
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.color(withType: .gradientPrimaryEnd)
            button.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        case .secondaryBackground(let customHeight): return Style<UIButton> { button in
            let buttonHeight = self.buttonHeight(fromCustomHeight: customHeight)
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.color(withType: .secondary)
            button.setTitleColor(ColorPalette.color(withType: .tertiaryText), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        case .loadingErrorStyle: return Style<UIButton> { button in
            let buttonHeight = Constants.Style.DefaultTextButtonHeight
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.loadingErrorPrimaryColor
            button.setTitleColor(ColorPalette.loadingErrorSecondaryColor, for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        case .feed: return Style<UIButton> { button in
            let buttonHeight = Constants.Style.FeedCellButtonHeight
            button.heightConstraintValue = buttonHeight
            button.layer.cornerRadius = buttonHeight / 2.0
            button.backgroundColor = ColorPalette.color(withType: .secondary)
            button.setTitleColor(ColorPalette.color(withType: .primaryText), for: .normal)
            button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .header2).font
            button.addShadowButton()
            }
        }
    }
        
    private func buttonHeight(fromCustomHeight customHeight: CGFloat?) -> CGFloat {
        if let customHeight = customHeight {
            return customHeight
        } else {
            return Constants.Style.DefaultTextButtonHeight
        }
    }
}
