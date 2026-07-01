//
//  WelcomeViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout

class WelcomeViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    
    private lazy var continueButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.secondaryBackground(customHeight: nil).style)
        button.setTitle(StringsProvider.string(forKey: .welcomeStartButton), for: .normal)
        button.addTarget(self, action: #selector(self.showIntro), for: .touchUpInside)
        return button
    }()
    
    private var headerImageView: UIImageView?
    
    init() {
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.repository = Services.shared.repository
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addGradientView(GradientView(type: .primaryBackground))

        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))

        stackView.addImage(withImage: ImagePalette.image(withName: .fyamLogoSpecific),
                           color: .clear,
                           sizeDimension: 136)
        stackView.addBlankSpace(space: 40)
        self.headerImageView = stackView.addHeaderImage(image: ImagePalette.image(withName: .mainLogo))
        // Presence-based, host-injectable partner logo. Prefer the canonical `partner_logo`
        // and fall back to the deprecated `czi_logo` for host apps still shipping the legacy key.
        // Both the artwork and the gap above it live inside this branch, so studies without any
        // partner asset render nothing (no empty box / dead space).
        if let partnerLogoImage = ImagePalette.image(withName: .partnerLogo)
            ?? ImagePalette.image(withName: .cziLogo) {
            stackView.addBlankSpace(space: 63)
            stackView.addArrangedSubview(self.makePartnerLogoView(image: partnerLogoImage, width: 195))
        }
        stackView.addBlankSpace(space: 66)
        stackView.addArrangedSubview(self.continueButton)
        stackView.addBlankSpace(space: 50)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.headerImageView?.syncWithPhase(repository: self.repository, imageName: .mainLogo)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.getStarted.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)

        self.continueButton.alpha = 0
        UIView.animate(withDuration: 0.8, delay: 0.0, options: .curveEaseInOut, animations: { [weak self] in
            guard let self = self else { return }
            self.continueButton.alpha = 1
        }, completion: nil)
        
        self.navigator.checkForNotificationPermission(presenter: self)
    }
    
    // MARK: Helpers

    /// Builds a horizontally-centered partner-logo view sized to a fixed width while preserving
    /// the source image's aspect ratio, so the wide landscape lockup is never stretched/distorted
    /// regardless of the host asset's pixel dimensions.
    private func makePartnerLogoView(image: UIImage, width: CGFloat) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        containerView.addSubview(imageView)

        imageView.autoPinEdge(toSuperviewEdge: .top)
        imageView.autoPinEdge(toSuperviewEdge: .bottom)
        imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0, relation: .greaterThanOrEqual)
        imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0, relation: .greaterThanOrEqual)
        imageView.autoSetDimension(.width, toSize: width)
        if image.size.width > 0 {
            let aspectRatio = image.size.height / image.size.width
            imageView.autoMatch(.height, to: .width, of: imageView, withMultiplier: aspectRatio)
        }
        return containerView
    }

    // MARK: Actions

    @objc private func showIntro() {
        self.navigator.showIntro(presenter: self)
    }
}
