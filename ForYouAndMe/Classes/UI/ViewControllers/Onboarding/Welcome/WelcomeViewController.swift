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
        stackView.addBlankSpace(space: 63)
        stackView.addHeaderImage(image: ImagePalette.image(withName: .cziLogo))
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
    
    // MARK: Actions
    
    @objc private func showIntro() {
        self.navigator.showIntro(presenter: self)
    }
}
