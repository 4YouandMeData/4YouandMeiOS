//
//  SingleTextHeaderView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import UIKit

class SingleTextHeaderView: UIView {
    
    private static let headerHeight: CGFloat = 64.0
    
    private let titleLabel = UILabel()
    
    init() {
        super.init(frame: .zero)
        
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let innerHeaderView = UIView()
        self.addSubview(innerHeaderView)
        innerHeaderView.autoPinEdgesToSuperviewSafeArea()
        innerHeaderView.autoSetDimension(.height, toSize: Self.headerHeight)
        
        innerHeaderView.addSubview(self.titleLabel)
        self.titleLabel.autoCenterInSuperview()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func setTitleText(_ text: String) {
        self.titleLabel.attributedText = NSAttributedString.create(withText: text, fontStyle: .title, colorType: .secondaryText)
    }
}
