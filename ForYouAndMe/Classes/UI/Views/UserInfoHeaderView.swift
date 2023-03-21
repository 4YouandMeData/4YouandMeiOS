//
//  UserInfoHeaderView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/09/2020.
//

import UIKit

class UserInfoHeaderView: UIView {
    
    private var headerImageView: UIImageView?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private let titleLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title, colorType: .secondaryText)
    
    private let repository: Repository
    
    init() {
        self.repository = Services.shared.repository
        super.init(frame: .zero)
        
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 39.0
        
        self.headerImageView = stackView.addHeaderImage(image: ImagePalette.image(withName: .mainLogo), height: 100.0)
        stackView.addArrangedSubview(self.titleLabel)
        
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 20.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 30.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func setTitle(_ text: String) {
        self.titleLabel.attributedText = NSAttributedString.create(withText: text,
                                                                   attributedTextStyle: self.titleLabelAttributedTextStyle)
    }
    
    public func refreshUI() {
        self.headerImageView?.syncWithPhase(repository: self.repository, imageName: .mainLogo)
    }
}
