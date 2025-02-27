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
    
    private let headerView = AboutYouHeaderView()
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("AboutYouViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        self.view.addSubview(self.headerView)
        self.headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        self.headerView.closeButton.addTarget(self, action: #selector(self.closeButtonDidPressed), for: .touchUpInside)
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: self.headerView, withOffset: 30)
        
        if let userInfoParameters = self.repository.currentUser?.customData, userInfoParameters.count > 0 {
            let userInfoTitle = StringsProvider.string(forKey: .aboutYouUserInfo)
            let userInfo = GenericListItemView(withTitle: userInfoTitle,
                                               image: ImagePalette.templateImage(withName: .userInfoIcon) ?? UIImage(),
                                               colorType: .primary,
                                               style: .flatStyle,
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
                                                 image: ImagePalette.templateImage(withName: .devicesIcon) ?? UIImage(),
                                                 colorType: .primary,
                                                 style: .flatStyle,
                                                 gestureCallback: { [weak self] in
                                                    guard let navigationController = self?.navigationController else {
                                                        fatalError("Navigation Controller is not present")
                                                    }
                                                    self?.navigator.showAppsAndDevices(navigationController: navigationController,
                                                                                       title: appsAndDevicesTitle)
                                                 })
        self.scrollStackView.stackView.addArrangedSubview(appsAndDevices)
        
        self.scrollStackView.stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .inactive),
                                                        inset: 21,
                                                        isVertical: false)
        // TODO: temporaly disabled
//        if OnboardingSectionProvider.userConsentSectionExists {
//            let consentTitle = StringsProvider.string(forKey: .aboutYouReviewConsent)
//            let reviewConsent = GenericListItemView(withTitle: consentTitle,
//                                                    image: ImagePalette.templateImage(withName: .reviewConsentIcon) ?? UIImage(),
//                                                    colorType: .primary,
//                                                    gestureCallback: { [weak self] in
//                                                        guard let navigationController = self?.navigationController else {
//                                                            fatalError("Navigation Controller is not present")
//                                                        }
//                                                        self?.navigator.showReviewConsent(navigationController: navigationController)
//                                                    })
//            self.scrollStackView.stackView.addArrangedSubview(reviewConsent)
//        }
        
        let permissionTitle = StringsProvider.string(forKey: .aboutYouPermissions)
        let permissions = GenericListItemView(withTitle: permissionTitle,
                                              image: ImagePalette.templateImage(withName: .permissionIcon) ?? UIImage(),
                                              colorType: .primary,
                                              style: .flatStyle,
                                              gestureCallback: { [weak self] in
                                                guard let navigationController = self?.navigationController else {
                                                    fatalError("Navigation Controller is not present")
                                                }
                                                self?.navigator.showPermissions(navigationController: navigationController,
                                                                                title: permissionTitle)
                                              })
        self.scrollStackView.stackView.addArrangedSubview(permissions)
        
        if Int(StringsProvider.string(forKey: .dailySurveyTimingHidden)) ?? 0 == 0 {
            let surveyScheduleTitle = StringsProvider.string(forKey: .aboutYouDailySurveyTiming)
            let surveySchedule = GenericListItemView(withTitle: surveyScheduleTitle,
                                                     image: ImagePalette.templateImage(withName: .timingIcon) ?? UIImage(),
                                                     colorType: .primary,
                                                     style: .flatStyle,
                                                     gestureCallback: { [weak self] in
                                                        guard let navigationController = self?.navigationController else {
                                                            fatalError("Navigation Controller is not present")
                                                        }
                                                    self?.navigator.showSurveySchedule(navigationController: navigationController,
                                                                                    title: surveyScheduleTitle)
                                                  })
            self.scrollStackView.stackView.addArrangedSubview(surveySchedule)
        }
        
        #if DEBUG
        if Constants.Test.EnableHealthKitCachePurgeButton {
            self.scrollStackView.stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .inactive),
                                                            inset: 21,
                                                            isVertical: false)

            let healthKitCachePurgeButton = GenericListItemView(withTitle: "Debug - Purge Healthkit cache",
                                                                image: UIImage(),
                                                                colorType: .primary,
                                                                style: .flatStyle,
                                                                gestureCallback: {
                Services.shared.storageServices.resetHealthKitCache()
            })
            
            self.scrollStackView.stackView.addArrangedSubview(healthKitCachePurgeButton)

            #if MIRSPIROMETRY
            
            // MARK: Mir Spirometry

            let mirSpirometryConnectButton = GenericListItemView(withTitle: "Debug - Mir Spirometry Connect",
                                                                 image: UIImage(),
                                                                 colorType: .primary,
                                                                 style: .flatStyle,
                                                                 gestureCallback: {
                
                Services.shared.storageServices.mirSpirometryConnect()
            })
            
            let mirSpirometryRunTestButton = GenericListItemView(withTitle: "Debug - Mir Spirometry Run Test",
                                                                 image: UIImage(),
                                                                 colorType: .primary,
                                                                 style: .flatStyle,
                                                                 gestureCallback: {
                
                Services.shared.storageServices.mirSpirometryRunTest()
            })
            
            let mirSpirometryDisconnectButton = GenericListItemView(withTitle: "Debug - Mir Spirometry Disconnect",
                                                                    image: UIImage(),
                                                                    colorType: .primary,
                                                                    style: .flatStyle,
                                                                    gestureCallback: {
                
                Services.shared.storageServices.mirSpirometryDisconnect()
            })

            let mirSpirometryStartDiscoverDevicesButton = GenericListItemView(withTitle: "Debug - Mir Spirometry Start Discover Devices",
                                                                    image: UIImage(),
                                                                    colorType: .primary,
                                                                    style: .flatStyle,
                                                                    gestureCallback: {
                
                Services.shared.storageServices.mirSpirometryStartDiscoverDevices()
            })

            let mirSpirometryStopDiscoverDevicesButton = GenericListItemView(withTitle: "Debug - Mir Spirometry Stop Discover Devices",
                                                                    image: UIImage(),
                                                                    colorType: .primary,
                                                                    style: .flatStyle,
                                                                    gestureCallback: {
                
                Services.shared.storageServices.mirSpirometryStopDiscoverDevices()
            })

            self.scrollStackView.stackView.addArrangedSubview(mirSpirometryConnectButton)
            self.scrollStackView.stackView.addArrangedSubview(mirSpirometryRunTestButton)
            self.scrollStackView.stackView.addArrangedSubview(mirSpirometryDisconnectButton)
            self.scrollStackView.stackView.addArrangedSubview(mirSpirometryStartDiscoverDevicesButton)
            self.scrollStackView.stackView.addArrangedSubview(mirSpirometryStopDiscoverDevicesButton)

            #endif
        }
        #endif
        
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
        self.headerView.refreshUI()
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.aboutYou.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    @objc private func closeButtonDidPressed() {
        self.customCloseButtonPressed()
    }
}
