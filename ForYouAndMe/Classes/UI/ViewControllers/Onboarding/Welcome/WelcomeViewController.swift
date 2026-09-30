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

        // Host-injectable partner logo: prefer the canonical `partner_logo`, fall back to the
        // deprecated `czi_logo`. When present, use an explicit layout that keeps the main logo
        // perfectly centered on screen and places the partner logo midway between it and the Get
        // Started button. Studies without a partner asset keep the original stacked layout.
        if let partnerLogoImage = ImagePalette.image(withName: .partnerLogo)
            ?? ImagePalette.image(withName: .cziLogo) {
            self.setupCenteredLayout(partnerLogoImage: partnerLogoImage)
        } else {
            self.setupStackedLayout()
        }
    }

    // MARK: Layout

    /// Original stacked layout, used when the study ships no partner logo. Preserved verbatim so
    /// those studies remain visually unchanged.
    private func setupStackedLayout() {
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
        stackView.addBlankSpace(space: 63)
        stackView.addHeaderImage(image: ImagePalette.image(withName: .cziLogo))
        stackView.addBlankSpace(space: 66)
        stackView.addArrangedSubview(self.continueButton)
        stackView.addBlankSpace(space: 50)
    }

    /// Explicit layout used when a host provides a partner logo: the main logo is pinned at 47% of
    /// the screen height at its natural size, the Get Started button near the bottom, the small
    /// FYAM logo (if any) at the top, and the partner logo at 71.5% of the screen height
    /// (per design review, matching the hosts' launch screens).
    private func setupCenteredLayout(partnerLogoImage: UIImage) {
        // The navigation bar is opaque (isTranslucent = false), so by default UIKit lays this view
        // out *below* the bar; "superview centerY" would then sit at ~56% of the physical screen.
        // Extend the layout under the bar so the centerY multipliers below are true screen
        // percentages.
        self.extendedLayoutIncludesOpaqueBars = true

        let margins = Constants.Style.DefaultHorizontalMargins

        let fyamLogoImageView = UIImageView(image: ImagePalette.image(withName: .fyamLogoSpecific))
        fyamLogoImageView.contentMode = .scaleAspectFit
        self.view.addSubview(fyamLogoImageView)
        fyamLogoImageView.autoAlignAxis(toSuperviewAxis: .vertical)
        fyamLogoImageView.autoPinEdge(toSuperviewSafeArea: .top)
        fyamLogoImageView.autoSetDimensions(to: CGSize(width: 136, height: 136))

        let mainLogoImageView = UIImageView(image: ImagePalette.image(withName: .mainLogo))
        mainLogoImageView.contentMode = .scaleAspectFit
        self.headerImageView = mainLogoImageView
        self.view.addSubview(mainLogoImageView)
        mainLogoImageView.autoAlignAxis(toSuperviewAxis: .vertical)
        // centerY = 0.94 * view.centerY -> 47% of the screen height.
        NSLayoutConstraint(item: mainLogoImageView,
                           attribute: .centerY,
                           relatedBy: .equal,
                           toItem: self.view,
                           attribute: .centerY,
                           multiplier: 0.94,
                           constant: 0).isActive = true
        mainLogoImageView.autoPinEdge(toSuperviewEdge: .leading, withInset: margins, relation: .greaterThanOrEqual)
        mainLogoImageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: margins, relation: .greaterThanOrEqual)

        self.view.addSubview(self.continueButton)
        self.continueButton.autoPinEdge(toSuperviewEdge: .leading, withInset: margins)
        self.continueButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: margins)
        self.continueButton.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 50)

        self.addPartnerLogo(image: partnerLogoImage, width: 195)
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

    /// Overlays a horizontally-centered partner logo on the view, vertically centered at 71.5% of
    /// the screen height (per design review). The width is fixed and the height follows the image
    /// aspect ratio, so the wide landscape lockup is never distorted.
    private func addPartnerLogo(image: UIImage, width: CGFloat) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        self.view.addSubview(imageView)

        imageView.autoAlignAxis(toSuperviewAxis: .vertical)
        imageView.autoSetDimension(.width, toSize: width)
        if image.size.width > 0 {
            let aspectRatio = image.size.height / image.size.width
            imageView.autoMatch(.height, to: .width, of: imageView, withMultiplier: aspectRatio)
        }

        // centerY = 1.43 * view.centerY -> 71.5% of the screen height.
        NSLayoutConstraint(item: imageView,
                           attribute: .centerY,
                           relatedBy: .equal,
                           toItem: self.view,
                           attribute: .centerY,
                           multiplier: 1.43,
                           constant: 0).isActive = true
    }

    // MARK: Actions

    @objc private func showIntro() {
        self.navigator.showIntro(presenter: self)
    }
}
