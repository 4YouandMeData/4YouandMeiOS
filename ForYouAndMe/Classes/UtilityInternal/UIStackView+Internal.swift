//
//  UIStackView+Internal.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 02/10/2020.
//

import DTCoreText

extension UIStackView {
    
    func addHTMLLabel(withText text: String,
                      fontStyle: FontStyle,
                      colorType: ColorType,
                      textAlignment: NSTextAlignment = .center,
                      underlined: Bool = false,
                      numberOfLines: Int = 0,
                      horizontalInset: CGFloat = 0) {
        
        //TO
        let attributedString = NSAttributedString.create(withText: text,
                                                         fontStyle: fontStyle,
                                                         colorType: colorType,
                                                         textAlignment: textAlignment,
                                                         underlined: underlined)
//        let options = [
//            DTDefaultLineHeightMultiplier: 1.2,
//            DTDefaultTextColor: ColorPalette.color(withType: colorType),
//            DTDefaultTextAlignment: NSNumber(value: textAlignment.rawValue)
//        ] as [String: Any]
//        let data = text.data(using: .utf8)
//        let attributedString = NSAttributedString(htmlData: data,
//                                                  options: nil,
//                                                  documentAttributes: nil)
//
        self.addHTMLLabel(attributedString: text.htmlToAttributedString ?? NSAttributedString(),
                          numberOfLines: numberOfLines,
                          horizontalInset: horizontalInset)
    }
    
    func addHTMLLabel(attributedString: NSAttributedString, numberOfLines: Int = 0, horizontalInset: CGFloat = 0) {
        let label = self.getHTMLLabel(attributedString: attributedString, numberOfLines: numberOfLines)
        self.addArrangedSubview(label, horizontalInset: horizontalInset)
    }
    
    private func getHTMLLabel(attributedString: NSAttributedString, numberOfLines: Int = 0) -> UITextView {
        let label = UITextView()
        label.attributedText = attributedString
        label.isEditable = false
        label.isUserInteractionEnabled = true
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
