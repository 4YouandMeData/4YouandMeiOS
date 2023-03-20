//
//  AboutYouHeaderView.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/09/2020.
//

import UIKit

class AboutYouHeaderView: UIView {
    
    let closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .secondaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private var headerImageView: UIImageView?
    
    private let repository: Repository
    
    init() {
        self.repository = Services.shared.repository
        super.init(frame: .zero)
        
        self.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 39
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        self.headerImageView = stackView.addHeaderImage(image: ImagePalette.image(withName: .mainLogo), height: 100.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .profileTitle),
                           fontStyle: .title,
                           colorType: .secondaryText)
        
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 20,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 30.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func onViewAppear() {
        self.headerImageView?.syncWithPhase(repository: self.repository, imageName: .mainLogo)
    }
}
