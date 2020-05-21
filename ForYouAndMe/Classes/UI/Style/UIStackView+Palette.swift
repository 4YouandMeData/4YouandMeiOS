//
//  UIStackView+Palette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 21/05/2020.
//

import Foundation

extension UIStackView {
    func addLabel(withText text: String,
                  fontStyle: FontStyle,
                  colorType: ColorType,
                  textAlignment: NSTextAlignment = .center,
                  underlined: Bool = false,
                  numberOfLines: Int = 0,
                  horizontalInset: CGFloat = 0) {
        let attributedString = NSAttributedString.create(withText: text,
                                                         fontStyle: fontStyle,
                                                         colorType: colorType,
                                                         textAlignment: textAlignment,
                                                         underlined: underlined)
        self.addLabel(attributedString: attributedString,
                      numberOfLines: numberOfLines,
                      horizontalInset: horizontalInset)
    }
    
    func addLabel(withText text: String,
                  fontStyle: FontStyle,
                  color: UIColor,
                  textAlignment: NSTextAlignment = .center,
                  underlined: Bool = false,
                  numberOfLines: Int = 0,
                  horizontalInset: CGFloat = 0) {
        let attributedString = NSAttributedString.create(withText: text,
                                                         fontStyle: fontStyle,
                                                         color: color,
                                                         textAlignment: textAlignment,
                                                         underlined: underlined)
        self.addLabel(attributedString: attributedString,
                      numberOfLines: numberOfLines,
                      horizontalInset: horizontalInset)
    }
}
