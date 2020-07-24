//
//  FeedEmptyView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/07/2020.
//

import UIKit

class FeedEmptyView: UIView {
    
    init(withTopOffset topOffset: CGFloat) {
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: topOffset + 80.0, left: 20.0, bottom: 0.0, right: 20.0),
                                               excludingEdge: .bottom)
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabFeedEmptyTitle), fontStyle: .title, colorType: .primaryText)
        stackView.addBlankSpace(space: 20.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabFeedEmptySubtitle), fontStyle: .paragraph, colorType: .primaryText)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
