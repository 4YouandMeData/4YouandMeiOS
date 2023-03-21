//
//  StudyInfoHeaderView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/07/2020.
//

import UIKit

class StudyInfoHeaderView: UIView {
    
    private var headerImageView: UIImageView?
    
    private let repository: Repository
    
    init() {
        self.repository = Services.shared.repository
        super.init(frame: .zero)
        
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 44.0
        
        self.headerImageView = stackView.addHeaderImage(image: ImagePalette.image(withName: .mainLogo), height: 120.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .tabStudyInfoTitle),
                           fontStyle: .title,
                           colorType: .secondaryText)
        
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 50.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 40.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func refreshUI() {
        self.headerImageView?.syncWithPhase(repository: self.repository, imageName: .mainLogo)
    }
}
