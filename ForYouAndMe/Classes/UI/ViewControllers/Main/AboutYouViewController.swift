//
//  AboutYouViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/09/2020.
//

import UIKit

class AboutYouViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = AboutYouHeaderView()
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        headerView.closeButton.addTarget(self, action: #selector(self.closeButtonDidPressed), for: .touchUpInside)
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        
        if let userInfoParameters = self.repository.userInfoParameters, userInfoParameters.count > 0 {
            let userInfoTitle = StringsProvider.string(forKey: .aboutYouUserInfo)
            let userInfo = GenericListItemView(withTitle: userInfoTitle,
                templateImageName: .userInfoIcon,
                colorType: .primary,
                gestureCallback: { [weak self] in
                    guard let self = self else { return }
                    guard let navigationController = self.navigationController else {
                        assertionFailure("Missing expected navigation controller")
                        return
                    }
                    self.navigator.showUserInfoPage(navigationController: navigationController,
                                                     title: userInfoTitle,
                                                     userInfoParameters: userInfoParameters)
                    
            })
            self.scrollStackView.stackView.addArrangedSubview(userInfo)
        }
    
        let appsAndDevicesTitle = StringsProvider.string(forKey: .aboutYouAppsAndDevices)
        let appsAndDevices = GenericListItemView(withTitle: appsAndDevicesTitle,
            templateImageName: .devicesIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                self?.navigator.showAppsAndDevices(navigationController: self?.navigationController ?? UINavigationController(),
                                                   title: appsAndDevicesTitle)
        })
        self.scrollStackView.stackView.addArrangedSubview(appsAndDevices)
        
        self.scrollStackView.stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .inactive),
                                                        inset: 21,
                                                        isVertical: false)
        
        let consentTitle = StringsProvider.string(forKey: .aboutYouReviewConsent)
        let reviewConsent = GenericListItemView(withTitle: consentTitle,
            templateImageName: .reviewConsentIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                self?.navigator.showReviewConsent(navigationController: self?.navigationController ?? UINavigationController())
        })
        self.scrollStackView.stackView.addArrangedSubview(reviewConsent)
        
        let permissionTitle = StringsProvider.string(forKey: .aboutYouPermissions)
        let permissions = GenericListItemView(withTitle: permissionTitle,
            templateImageName: .permissionIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                self?.navigator.showPermissions(navigationController: self?.navigationController ?? UINavigationController(),
                title: permissionTitle)
        })
        self.scrollStackView.stackView.addArrangedSubview(permissions)
        
        self.scrollStackView.stackView.addBlankSpace(space: 57)
        let disclaimerFooter = StringsProvider.string(forKey: .disclaimerFooter)
        self.scrollStackView.stackView.addLabel(withText: disclaimerFooter,
                                                fontStyle: .paragraph,
                                                colorType: .fourthText,
                                                textAlignment: .left,
                                                horizontalInset: 21)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.aboutYou.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    private func showPage(page: Page, isModal: Bool) {
        self.navigator.showInfoDetailPage(presenter: self, page: page, isModal: isModal)
    }
    
    @objc private func closeButtonDidPressed() {
        self.customCloseButtonPressed()
    }
}
