//
//  NSAttributedString+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 21/05/2020.
//

import Foundation

extension NSAttributedString {
    var mutable: NSMutableAttributedString { return NSMutableAttributedString(attributedString: self) }
    var fullRange: NSRange { return NSRange(location: 0, length: self.length) }
    
    class func create(withText text: String,
                      font: UIFont,
                      lineSpacing: CGFloat,
                      uppercase: Bool = false,
                      color: UIColor,
                      textAlignment: NSTextAlignment = .center,
                      underlined: Bool = false) -> NSAttributedString {
        guard false == text.isEmpty else {
            return NSAttributedString(string: text)
        }
        let mutableAttributedString = NSMutableAttributedString(string: uppercase ? text.uppercased() : text)
        
        mutableAttributedString.setFont(font)
        mutableAttributedString.setLineSpacing(lineSpacing)
        mutableAttributedString.setColor(color)
        mutableAttributedString.setTextAlignment(textAlignment)
        if underlined {
            mutableAttributedString.addUnderline()
        }
        return mutableAttributedString
    }
    
    /// Returns a copy of the attributed string whose paragraph style uses the given line break mode.
    ///
    /// UILabel ignores `adjustsFontSizeToFitWidth` on multiline attributed text unless the
    /// paragraph style line break mode is `.byTruncatingTail`. The strings built by
    /// `create(withText:...)` carry a paragraph style whose line break mode defaults to
    /// `.byWordWrapping`, which silently disables the font auto-shrink (FUAM-3562).
    func applyingLineBreakMode(_ lineBreakMode: NSLineBreakMode) -> NSAttributedString {
        guard self.length > 0 else { return self }
        let mutableAttributedString = self.mutable
        mutableAttributedString.setLineBreakMode(lineBreakMode)
        return mutableAttributedString
    }

    fileprivate func getMutableParagraphStyle(forRange range: NSRange? = nil) -> NSMutableParagraphStyle {
        if let paragraphStyle = self.attribute(.paragraphStyle, at: 0,
                                               longestEffectiveRange: nil,
                                               in: range ?? self.fullRange) as? NSParagraphStyle,
            let mutableParagraphStyle = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle {
            return mutableParagraphStyle
        } else {
            return NSMutableParagraphStyle()
        }
    }
}

extension NSMutableAttributedString {
    func setFont(_ font: UIFont, range: NSRange? = nil) {
        self.addAttribute(.font, value: font, range: range ?? self.fullRange)
    }
    
    func setColor(_ color: UIColor, range: NSRange? = nil) {
        self.addAttribute(.foregroundColor, value: color, range: range ?? self.fullRange)
    }
    
    func addUnderline(range: NSRange? = nil) {
        self.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range ?? self.fullRange)
    }
    
    func setLineSpacing(_ lineSpacing: CGFloat, range: NSRange? = nil) {
        let paragraphStyle = self.getMutableParagraphStyle(forRange: range)
        paragraphStyle.lineSpacing = lineSpacing
        self.updateParagraphStyle(withParagraphStyle: paragraphStyle, range: range)
    }
    
    func setLineBreakMode(_ lineBreakMode: NSLineBreakMode, range: NSRange? = nil) {
        let paragraphStyle = self.getMutableParagraphStyle(forRange: range)
        paragraphStyle.lineBreakMode = lineBreakMode
        self.updateParagraphStyle(withParagraphStyle: paragraphStyle, range: range)
    }

    func setTextAlignment(_ textAlignment: NSTextAlignment, range: NSRange? = nil) {
        let paragraphStyle = self.getMutableParagraphStyle(forRange: range)
        paragraphStyle.alignment = textAlignment
        self.updateParagraphStyle(withParagraphStyle: paragraphStyle, range: range)
    }
    
    func addAttributes(fromAttributedString attributedString: NSAttributedString, range: NSRange? = nil) {
        attributedString.attributes(at: 0, effectiveRange: nil).forEach { attributedData in
            self.addAttribute(attributedData.key, value: attributedData.value, range: range ?? self.fullRange)
        }
    }
    
    fileprivate func updateParagraphStyle(withParagraphStyle paragraphStyle: NSParagraphStyle, range: NSRange? = nil) {
        self.addAttribute(.paragraphStyle, value: paragraphStyle, range: range ?? self.fullRange)
    }
}
