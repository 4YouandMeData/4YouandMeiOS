//
//  NSAttributedString+Palette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 21/05/2020.
//

import Foundation

extension NSAttributedString {
    class func create(withText text: String,
                      fontStyle: FontStyle,
                      colorType: ColorType,
                      textAlignment: NSTextAlignment = .center,
                      underlined: Bool = false) -> NSAttributedString {
        return NSAttributedString.create(withText: text,
                                         fontStyle: fontStyle,
                                         color: ColorPalette.color(withType: colorType),
                                         textAlignment: textAlignment,
                                         underlined: underlined)
    }
    
    class func create(withText text: String,
                      fontStyle: FontStyle,
                      color: UIColor,
                      textAlignment: NSTextAlignment = .center,
                      underlined: Bool = false) -> NSAttributedString {
        let fontStyleData = FontPalette.fontStyleData(forStyle: fontStyle)
        return NSAttributedString.create(withText: text,
                                         font: fontStyleData.font,
                                         lineSpacing: fontStyleData.lineSpacing,
                                         uppercase: fontStyleData.uppercase,
                                         color: color,
                                         textAlignment: textAlignment,
                                         underlined: underlined)
    }
}
