//
//  File.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/09/2020.
//

import UIKit

class InfoDetailHeaderView: UIView {
    
    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .backButtonNavigation), for: .normal)
        button.tintColor = ColorPalette.color(withType: .secondaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    init(withTitle title: String) {
        
        super.init(frame: .zero)
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let containerView = UIView()
        containerView.autoSetDimension(.height, toSize: 80)
        self.addSubview(containerView)
        containerView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0,
                                                                         left: Constants.Style.DefaultHorizontalMargins,
                                                                         bottom: 0,
                                                                         right: Constants.Style.DefaultHorizontalMargins))
        
        containerView.addSubview(self.backButton)
        self.backButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        
        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString.create(withText: title,
                                                              fontStyle: .title,
                                                              colorType: .secondaryText)
        containerView.addSubview(titleLabel)
        titleLabel.autoCenterInSuperview()
        titleLabel.autoPinEdge(.leading, to: .trailing, of: self.backButton, withOffset: 16)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
