//
//  DiaryNoteEmptyView.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import UIKit

class DiaryNoteEmptyView: UIView {
    
    init(withTopOffset topOffset: CGFloat) {
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.color(withType: .secondaryBackgroungColor)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 20.0, bottom: 0.0, right: 20.0),
                                               excludingEdge: .bottom)
        
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .diaryNoteEmptyViewTitle)),
                           fontStyle: .header2,
                           colorType: .primaryText)
        stackView.addBlankSpace(space: 20.0)
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .diaryNoteEmptyViewDescription)),
                           fontStyle: .paragraph,
                           colorType: .primaryText)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
