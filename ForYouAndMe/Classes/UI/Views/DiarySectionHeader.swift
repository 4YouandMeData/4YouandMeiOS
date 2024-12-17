//
//  DiarySectionHeader.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 17/12/24.
//

import UIKit

class DiarySectionHeader: UITableViewHeaderFooterView {
    
    private let titleLabel: UILabel = UILabel()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        self.addSubview(self.titleLabel)
        self.titleLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16,
                                                                        left: Constants.Style.DefaultHorizontalMargins,
                                                                        bottom: 8.0,
                                                                        right: Constants.Style.DefaultHorizontalMargins))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Public Methods
    
    public func display(text: String) {
        let fontStyleData = FontPalette.fontStyleData(forStyle: .paragraph)
        let attributedTextStyle = AttributedTextStyle(fontStyle: .paragraph,
                                                      colorType: .primaryText,
                                                      textAlignment: .left)
        let font = UIFont.boldSystemFont(ofSize: 16.0)
        
        self.titleLabel.attributedText = NSAttributedString.create(withText: text,
                                                                   font: font,
                                                                   lineSpacing: fontStyleData.lineSpacing,
                                                                   uppercase: fontStyleData.uppercase,
                                                                   color: ColorPalette.color(withType: .primaryText),
                                                                   textAlignment: attributedTextStyle.textAlignment,
                                                                   underlined: attributedTextStyle.underlined)
    }
}
