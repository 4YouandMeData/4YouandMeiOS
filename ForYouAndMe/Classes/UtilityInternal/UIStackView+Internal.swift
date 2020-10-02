//
//  UIStackView+Internal.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 02/10/2020.
//

import DTCoreText

extension UIStackView {
    func addHTMLTextView(withText text: String,
                      fontStyle: FontStyle,
                      colorType: ColorType,
                      textAlignment: NSTextAlignment = .center,
                      horizontalInset: CGFloat = 0) {

        guard let htmlString = text.htmlToAttributedString else {
            self.addLabel(withText: text, fontStyle: fontStyle, colorType: colorType)
            fatalError("error parsing HTML text")
        }
        
        let attributedString = NSMutableAttributedString(attributedString: htmlString)
        attributedString.setColor(ColorPalette.color(withType: colorType))
        attributedString.setFont(FontPalette.fontStyleData(forStyle: fontStyle).font)
        attributedString.setTextAlignment(textAlignment)
        
        self.addHTMLTextView(attributedString: attributedString,
                          horizontalInset: horizontalInset)
    }
    
    func addHTMLTextView(attributedString: NSAttributedString, horizontalInset: CGFloat = 0) {
        let label = self.getHTMLTextView(attributedString: attributedString)
        self.addArrangedSubview(label, horizontalInset: horizontalInset)
    }
    
    private func getHTMLTextView(attributedString: NSAttributedString) -> UITextView {

        let label = UITextView()
        label.attributedText = attributedString
        label.isEditable = false
        label.isUserInteractionEnabled = true
        label.isScrollEnabled = false
        label.dataDetectorTypes = [.all]
        label.backgroundColor = .clear
        label.dataDetectorTypes = [.all]
        label.autoSetDimensions(to: CGSize(width: 50, height: 100))
        return label
    }
}

extension String {
    var htmlToAttributedString: NSAttributedString? {
        guard let data = data(using: .utf8) else { return nil }
        do {
            return try NSAttributedString(data: data,
                                          options: [.documentType: NSAttributedString.DocumentType.html,
                                                    .characterEncoding: String.Encoding.utf8.rawValue],
                                          documentAttributes: nil)
        } catch {
            return nil
        }
    }
    var htmlToString: String {
        return htmlToAttributedString?.string ?? ""
    }
}
