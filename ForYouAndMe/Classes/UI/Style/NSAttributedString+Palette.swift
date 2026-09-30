//
//  NSAttributedString+Palette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 21/05/2020.
//

import Foundation

extension NSAttributedString {
    
    class func create(withText text: String,
                      attributedTextStyle: AttributedTextStyle) -> NSAttributedString {
        let textColor = ColorPalette.color(withType: attributedTextStyle.colorType).applyAlpha(attributedTextStyle.alpha)
        return NSAttributedString.create(withText: text,
                                         fontStyle: attributedTextStyle.fontStyle,
                                         color: textColor,
                                         textAlignment: attributedTextStyle.textAlignment,
                                         underlined: attributedTextStyle.underlined)
    }
    
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

    /// FUAM-3637: builds a title whose font is shrunk (down to `floorScale`, via an ~8-step
    /// binary search on the font scale) so `text` fits `maxLines` within `availableWidth`, then
    /// returns a `.byTruncatingTail` copy for display (paired with `numberOfLines = maxLines` and
    /// `.byTruncatingTail` as the below-floor fallback).
    ///
    /// The fit is MEASURED on a `.byWordWrapping` copy on purpose: `boundingRect` on a
    /// `.byTruncatingTail` string reports a single line (Foundation treats truncating modes as
    /// non-wrapping), so measuring the display string makes every scale "fit" and silently no-ops
    /// the shrink. The font is rebuilt per candidate from the Dynamic-Type-scaled base font, so the
    /// returned string must NOT be cached across content-size-category changes.
    class func createFitted(withText text: String,
                            fontStyle: FontStyle,
                            colorType: ColorType,
                            availableWidth: CGFloat,
                            maxLines: Int = 2,
                            floorScale: CGFloat = 0.6,
                            textAlignment: NSTextAlignment = .center) -> NSAttributedString {
        return self.createFitted(withText: text,
                                 fontStyle: fontStyle,
                                 color: ColorPalette.color(withType: colorType),
                                 availableWidth: availableWidth,
                                 maxLines: maxLines,
                                 floorScale: floorScale,
                                 textAlignment: textAlignment)
    }

    class func createFitted(withText text: String,
                            fontStyle: FontStyle,
                            color: UIColor,
                            availableWidth: CGFloat,
                            maxLines: Int = 2,
                            floorScale: CGFloat = 0.6,
                            textAlignment: NSTextAlignment = .center) -> NSAttributedString {
        let styleData = FontPalette.fontStyleData(forStyle: fontStyle)
        let baseFont = styleData.font
        let lineSpacing = styleData.lineSpacing

        func fits(atScale scale: CGFloat) -> Bool {
            let scaledFont = baseFont.withSize(baseFont.pointSize * scale)
            // Measure a word-wrapping copy — a truncating copy would report one line and defeat the fit.
            let measured = NSMutableAttributedString(string: text)
            measured.setFont(scaledFont)
            measured.setLineSpacing(lineSpacing)
            measured.setLineBreakMode(.byWordWrapping)
            let bounds = measured.boundingRect(with: CGSize(width: availableWidth,
                                                            height: .greatestFiniteMagnitude),
                                               options: [.usesLineFragmentOrigin], context: nil)
            // N wrapped lines measure as N*lineHeight + (N-1)*lineSpacing; the +1 absorbs rounding.
            let target = CGFloat(maxLines) * scaledFont.lineHeight + lineSpacing
            return bounds.height <= target + 1.0
        }

        var scale: CGFloat = 1.0
        if false == text.isEmpty && false == fits(atScale: 1.0) {
            var low = floorScale
            var high: CGFloat = 1.0
            for _ in 0..<8 {
                let mid = (low + high) / 2
                if fits(atScale: mid) { low = mid } else { high = mid }
            }
            scale = low
        }

        let scaledFont = baseFont.withSize(baseFont.pointSize * scale)
        let display = NSAttributedString.create(withText: text,
                                                font: scaledFont,
                                                lineSpacing: lineSpacing,
                                                uppercase: styleData.uppercase,
                                                color: color,
                                                textAlignment: textAlignment)
        return display.applyingLineBreakMode(.byTruncatingTail)
    }
}
