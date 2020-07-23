//
//  FeedListSectionHeader.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit

class FeedListSectionHeader: UITableViewHeaderFooterView {
    
    private let titleLabel: UILabel = UILabel()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        self.addSubview(self.titleLabel)
        self.titleLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16,
                                                                        left: Constants.Style.DefaultHorizontalMargins,
                                                                        bottom: 0,
                                                                        right: Constants.Style.DefaultHorizontalMargins))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Public Methods
    
    public func display(text: String) {
        self.titleLabel.attributedText = NSAttributedString.create(withText: text,
                                                                   fontStyle: .paragraph,
                                                                   colorType: .primaryText,
                                                                   textAlignment: .left)
    }
}
