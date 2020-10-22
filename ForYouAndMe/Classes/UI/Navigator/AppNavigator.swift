//
//  AppNavigator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import SVProgressHUD
import RxSwift
import SafariServices

enum InternalDeeplinkKey: String {
    case feed
    case task
    case userData = "your_data"
    case studyInfo = "study_info"
    case aboutYou = "about_you"
    case faq
    case rewards
    case contacts
}

class AppNavigator {
    
    enum MainTab: Int, CaseIterable { case feed = 0, task = 1, userData = 2, studyInfo = 3 }
    
    static let defaultStartingTab: MainTab = .feed
    
    private var progressHudCount = 0
    
    private var setupCompleted = false
    private var currentCoordinator: Any?
    private var currentActivityCoordinator: ActivitySectionCoordinator?
    
    private var isTaskInProgress: Bool {
        return false
        // TODO: Fix this! currentActivityCoordinator is not always release due to some
        // shared close buttons that dismiss the task without clearing this variable
//        return nil != self.currentActivityCoordinator
    }
    
    private let repository: Repository
    private let analytics: AnalyticsService
    private let deeplinkService: DeeplinkService
    private let window: UIWindow
    
    private let disposeBag = DisposeBag()
    
    init(withRepository repository: Repository, analytics: AnalyticsService, deeplinkService: DeeplinkService, window: UIWindow) {
        self.repository = repository
        self.analytics = analytics
        self.deeplinkService = deeplinkService
        self.window = window
        
        // Needed to block user interaction!! :S
        SVProgressHUD.setDefaultMaskType(.black)
    }
    
    // MARK: - Initialization
    
    func showSetupScreen() {
        self.window.rootViewController = LoadingViewController<()>(loadingMode: .initialSetup)
    }
    
    func showSetupCompleted() {
        self.onStartup()
    }
    
    // MARK: - Top level
    
    func onStartup() {
        
        // Convenient entry point to test each app module atomically,
        // without going through all the official flow
        #if DEBUG
        if let testSection = Constants.Test.Section {
            let testNavigationViewController = UINavigationController(rootViewController: UIViewController())
            
            testNavigationViewController.preventPopWithSwipe()
            self.window.rootViewController = testNavigationViewController
            
            switch testSection {
            case .introVideo: self.showIntroVideo(navigationController: testNavigationViewController)
            case .screeningSection: self.startScreeningSection(navigationController: testNavigationViewController)
            case .informedConsentSection: self.startInformedConsentSection(navigationController: testNavigationViewController)
            case .consentSection: self.startConsentSection(navigationController: testNavigationViewController)
            case .optInSection: self.startOptInSection(navigationController: testNavigationViewController)
            case .consentUserDataSection: self.startUserContentDataSection(navigationController: testNavigationViewController)
            case .integrationSection: self.startIntegrationSection(navigationController: testNavigationViewController)
            }
            return
        }
        #endif
        
        self.setupCompleted = true
        if self.repository.isLoggedIn {
            var onboardingCompleted = self.repository.currentUser?.isOnboardingCompleted ?? false
            #if DEBUG
            if let testOnboardingCompleted = Constants.Test.OnboardingCompleted {
                onboardingCompleted = testOnboardingCompleted
            }
            #endif
            if onboardingCompleted {
                self.goHome()
            } else {
                self.deeplinkService.clearCurrentDeeplinkedData()
                // If onboarding is not completed, log out (restart from the very beginning)
                self.logOut()
            }
        } else {
            self.deeplinkService.clearCurrentDeeplinkedData()
            self.goToWelcome()
        }
    }
    
    public func abortOnboardingWithWarning(presenter: UIViewController) {
        let cancelAction = UIAlertAction(title: StringsProvider.string(forKey: .onboardingAbortCancel),
                                         style: .cancel,
                                         handler: nil)
        let confirmAction = UIAlertAction(title: StringsProvider.string(forKey: .onboardingAbortConfirm),
                                          style: .destructive,
                                          handler: { [weak self] _ in self?.abortOnboarding() })
        presenter.showAlert(withTitle: StringsProvider.string(forKey: .onboardingAbortTitle),
                            message: StringsProvider.string(forKey: .onboardingAbortMessage),
                            actions: [cancelAction, confirmAction],
                            tintColor: ColorPalette.color(withType: .primary))
    }
    
    public func abortOnboarding() {
        
        if (self.currentCoordinator as? ScreeningSectionCoordinator) != nil {
            self.analytics.track(event: .cancelDuringScreeningQuestion(""))
        } else if let coordinator = self.currentCoordinator as? InformedConsentSectionCoordinator {
            if coordinator.currentPage != nil {
                self.analytics.track(event: .cancelDuringInformedConsent(coordinator.currentPage?.id ?? ""))
            } else if coordinator.currentQuestion != nil {
                self.analytics.track(event: .cancelDuringComprehensionQuiz(coordinator.currentQuestion?.id ?? ""))
            }
        } else if (self.currentCoordinator as? ConsentSectionCoordinator) != nil {
            self.analytics.track(event: .consentDisagreed)
        }
        self.goToWelcome()
    }
    
    // MARK: - Welcome
    
    public func goToWelcome() {
        let navigationViewController = UINavigationController(rootViewController: WelcomeViewController())
        navigationViewController.preventPopWithSwipe()
        self.window.rootViewController = navigationViewController
    }
    
    public func showIntro(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(IntroViewController(), animated: true)
    }
    
    public func showSetupLater(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(SetupLaterViewController(), animated: true)
    }
    
    public func goBackToWelcome(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.popToExpectedViewController(ofClass: WelcomeViewController.self, animated: true)
    }
    
    // MARK: - Login
    
    public func showLogin(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(PhoneVerificationViewController(), animated: true)
    }
    
    public func showCodeValidation(countryCode: String, phoneNumber: String, presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        let codeValidationViewController = CodeValidationViewController(countryCode: countryCode, phoneNumber: phoneNumber)
        navigationController.pushViewController(codeValidationViewController, animated: true)
    }
    
    public func showPrivacyPolicy(presenter: UIViewController) {
        guard let url = URL(string: StringsProvider.string(forKey: .urlPrivacyPolicy)) else {
            assertionFailure("Invalid Url for privacy policy")
            return
        }
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.privacyPolicy.rawValue,
                                                  screenClass: String(describing: type(of: presenter))))
        self.openWebView(withTitle: "", url: url, presenter: presenter)
    }
    
    public func showTermsOfService(presenter: UIViewController) {
        guard let url = URL(string: StringsProvider.string(forKey: .urlTermsOfService)) else {
            assertionFailure("Invalid Url for terms of service")
            return
        }
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.termsOfService.rawValue,
                                                  screenClass: String(describing: type(of: presenter))))
        self.openWebView(withTitle: "", url: url, presenter: presenter)
    }
    
    public func onLoginCompleted(presenter: UIViewController) {
        guard let currentUser = self.repository.currentUser else {
            assertionFailure("Missing current user right after login")
            return
        }
        if currentUser.isOnboardingCompleted {
            self.goHome()
        } else {
            self.startOnboarding(presenter: presenter)
        }
    }
    
    private func startOnboarding(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        self.showIntroVideo(navigationController: navigationController)
    }
    
    // MARK: Intro Video
    
    public func showIntroVideo(navigationController: UINavigationController) {
        navigationController.pushViewController(IntroVideoViewController(), animated: true)
    }
    
    public func onIntroVideoCompleted(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        self.startScreeningSection(navigationController: navigationController)
    }
    
    // MARK: Screening Questions
    
    public func startScreeningSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getScreeningSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.startInformedConsentSection(navigationController: navigationController)
            }
            let coordinator = ScreeningSectionCoordinator(withSectionData: section,
                                                          navigationController: navigationController,
                                                          completionCallback: completionCallback)
            self.currentCoordinator = coordinator
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Informed Consent
    
    public func startInformedConsentSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getInformedConsentSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.startConsentSection(navigationController: navigationController)
            }
            let coordinator = InformedConsentSectionCoordinator(withSectionData: section,
                                                                navigationController: navigationController,
                                                                completionCallback: completionCallback)
            self.currentCoordinator = coordinator
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Consent
    
    public func startConsentSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getConsentSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.analytics.track(event: .consentAgreed)
                self?.startOptInSection(navigationController: navigationController)
            }
            let coordinator = ConsentSectionCoordinator(withSectionData: section,
                                                        navigationController: navigationController,
                                                        completionCallback: completionCallback)
            self.currentCoordinator = coordinator
            return coordinator.getStartingPage()
        }
    }
    
    public func showReviewConsent(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getConsentSection(),
                                                hidesBottomBarWhenPushed: true,
                                                allowBackwardNavigation: true) { section -> UIViewController in
            let data = InfoPageListData(title: section.title,
                                        subtitle: section.subtitle,
                                        body: section.body,
                                        startingPage: section.welcomePage,
                                        pages: section.pages,
                                        mode: .view)
            return InfoPageListViewController(withData: data)
        }
    }
    
    // MARK: Opt-In
    
    public func startOptInSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getOptInSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.startUserContentDataSection(navigationController: navigationController)
            }
            let coordinator = OptInSectionCoordinator(withSectionData: section,
                                                      navigationController: navigationController,
                                                      completionCallback: completionCallback)
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Consent User Data
    
    public func startUserContentDataSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getUserConsentSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.startIntegrationSection(navigationController: navigationController)
            }
            let coordinator = ConsentUserDataSectionCoordinator(withSectionData: section,
                                                                navigationController: navigationController,
                                                                completionCallback: completionCallback)
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Integration
    
    public func startIntegrationSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getIntegrationSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.goHome()
            }
            let coordinator = IntegrationSectionCoordinator(withSectionData: section,
                                                            navigationController: navigationController,
                                                            completionCallback: completionCallback)
            return coordinator.getStartingPage()
        }
    }
    
    public func showIntegrationLogin(loginUrl: URL, navigationController: UINavigationController) {
        let viewController = ReactiveAuthWebViewController(withTitle: "",
                                                           url: loginUrl,
                                                           allowBackwardNavigation: true,
                                                           onSuccessCallback: { _ in
                                                            navigationController.popViewController(animated: true)
                                                           },
                                                           onFailureCallback: { _ in
                                                            navigationController.popViewController(animated: true)
                                                           })
        viewController.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(viewController, animated: true)
    }
    
    // MARK: Home
    
    public func goHome() {
        let tabBarController = UITabBarController()
        
        // Basically, we want the content not to fall behind the tab bar
        tabBarController.tabBar.isTranslucent = false
        
        // Colors
        tabBarController.tabBar.tintColor = ColorPalette.color(withType: .primaryText)
        tabBarController.tabBar.barTintColor = ColorPalette.color(withType: .secondary)
        tabBarController.tabBar.unselectedItemTintColor = ColorPalette.color(withType: .secondaryMenu)
        
        // Remove top line
        tabBarController.tabBar.barStyle = .black
        
        // Add shadow
        tabBarController.tabBar.addShadowLinear(goingDown: false)
        
        var viewControllers: [UIViewController] = []
        
        let titleFont = FontPalette.fontStyleData(forStyle: .menu).font
        
        MainTab.allCases.forEach { mainTab in
            switch mainTab {
            case .feed:
                let feedViewController = FeedViewController()
                let feedNavigationController = UINavigationController(rootViewController: feedViewController)
                feedNavigationController.preventPopWithSwipe()
                feedNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabFeed)
                feedNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabFeed)
                feedNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
                viewControllers.append(feedNavigationController)
            case .task:
                let taskViewController = TaskViewController()
                let taskNavigationController = UINavigationController(rootViewController: taskViewController)
                taskNavigationController.preventPopWithSwipe()
                taskNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabTask)
                taskNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabTask)
                taskNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
                viewControllers.append(taskNavigationController)
            case .userData:
                let userDataViewController = UserDataViewController()
                let userDataNavigationController = UINavigationController(rootViewController: userDataViewController)
                userDataNavigationController.preventPopWithSwipe()
                userDataNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabUserData)
                userDataNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabUserData)
                userDataNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
                viewControllers.append(userDataNavigationController)
            case .studyInfo:
                let studyInfoViewController = StudyInfoViewController()
                let studyInfoNavigationController = UINavigationController(rootViewController: studyInfoViewController)
                studyInfoNavigationController.preventPopWithSwipe()
                studyInfoNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabStudyInfo)
                studyInfoNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabStudyInfo)
                studyInfoNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
                viewControllers.append(studyInfoNavigationController)
            }
        }
        
        tabBarController.viewControllers = viewControllers
        tabBarController.selectedIndex = Self.defaultStartingTab.rawValue
        self.window.rootViewController = tabBarController
    }
    
    public func switchToFeedTab(presenter: UIViewController) {
        guard let tabBarController = presenter.tabBarController else { return }
        guard let feedViewControllerIndex = tabBarController.viewControllers?.firstIndex(where: { viewController in
            (viewController as? UINavigationController)?.viewControllers.first is FeedViewController
        }) else { return }
        self.analytics.track(event: .switchTab(StringsProvider.string(forKey: .tabFeed)))
        tabBarController.selectedIndex = feedViewControllerIndex
    }
    
    // MARK: Task
    
    public func startFeedFlow(withFeed feed: Feed, presenter: UIViewController) {
        if let schedulable = feed.schedulable {
            switch schedulable {
            case .quickActivity:
                print("AppNavigator - No section should be started for the quick activities")
            case .activity(let activity):
                guard let taskType = activity.taskType else {
                    assertionFailure("Missing task type for the current Activity")
                    break
                }
                self.startTaskSection(taskIdentifier: feed.id,
                                      taskType: taskType,
                                      taskOptions: nil,
                                      presenter: presenter)
            case .survey(let survey):
                self.pushProgressHUD()
                self.repository.getSurvey(surveyId: survey.id)
                    .subscribe(onSuccess: { [weak self] surveyGroup in
                        guard let self = self else { return }
                        self.popProgressHUD()
                        self.startSurveySection(withTaskIdentfier: feed.id,
                                                surveyGroup: surveyGroup,
                                                presenter: presenter)
                    }, onError: { [weak self] error in
                        guard let self = self else { return }
                        self.popProgressHUD()
                        self.handleError(error: error, presenter: presenter)
                    }).disposed(by: self.disposeBag)
            }
        } else if let notifiable = feed.notifiable {
            let urlString: String? = {
                switch notifiable {
                case .educational(let educational): return educational.urlString
                case .alert(let alert): return alert.urlString
                case .rewards(let rewards): return rewards.urlString
                }
            }()
            guard let notifiableUrl = urlString else {
                assertionFailure("AppNavigator - Missing notifiable url for given notifiable")
                return
            }
            self.handleNotifiableTile(notifiableUrl: notifiableUrl, presenter: presenter)
        } else {
            assertionFailure("Unhandle Type")
        }
    }
    
    public func startTaskSection(taskIdentifier: String, taskType: TaskType, taskOptions: TaskOptions?, presenter: UIViewController) {
        let completionCallback: NotificationCallback = { [weak self] in
            guard let self = self else { return }
            presenter.dismiss(animated: true, completion: nil)
            self.currentActivityCoordinator = nil
        }
        let coordinator: ActivitySectionCoordinator = {
            switch taskType {
            case .videoDiary:
                return VideoDiarySectionCoordinator(withTaskIdentifier: taskIdentifier,
                                                    completionCallback: completionCallback)
            case .camcogEbt, .camcogNbx, .camcogPvt:
                return CamcogSectionCoordinator(withTaskIdentifier: taskIdentifier,
                                                completionCallback: completionCallback,
                                                welcomePage: Constants.Camcog.DefaultWelcomePage,
                                                successPage: Constants.Camcog.DefaultSuccessPage)
            default:
                return TaskSectionCoordinator(withTaskIdentifier: taskIdentifier,
                                              taskType: taskType,
                                              taskOptions: taskOptions,
                                              welcomePage: nil,
                                              successPage: nil,
                                              completionCallback: completionCallback)
            }
        }()
        guard let startingPage = coordinator.getStartingPage() else {
            self.currentActivityCoordinator = nil
            self.handleError(error: nil, presenter: presenter)
            assertionFailure("Couldn't get starting view controller for current task type")
            return
        }
        self.analytics.track(event: .recordScreen(screenName: taskIdentifier,
                                                  screenClass: String(describing: type(of: self))))
        
        startingPage.modalPresentationStyle = .fullScreen
        presenter.present(startingPage, animated: true, completion: nil)
        self.currentActivityCoordinator = coordinator
    }
    
    public func startSurveySection(withTaskIdentfier taskIdentifier: String, surveyGroup: SurveyGroup, presenter: UIViewController) {
        let completionCallback: NotificationCallback = { [weak self] in
            guard let self = self else { return }
            presenter.dismiss(animated: true, completion: nil)
            self.currentActivityCoordinator = nil
        }
        
        let coordinator = SurveyGroupSectionCoordinator(withTaskIdentifier: taskIdentifier,
                                                        sectionData: surveyGroup,
                                                        navigationController: nil,
                                                        completionCallback: completionCallback)
        guard let startingPage = coordinator.getStartingPage() else {
            self.currentActivityCoordinator = nil
            self.handleError(error: nil, presenter: presenter)
            return
        }
        startingPage.modalPresentationStyle = .fullScreen
        presenter.present(startingPage, animated: true, completion: nil)
        
        self.currentActivityCoordinator = coordinator
    }
    
    public func handleNotifiableTile(notifiableUrl: String, presenter: UIViewController) {
        if let internalDeeplinkKey = InternalDeeplinkKey(rawValue: notifiableUrl) {
            self.handleInternalDeeplink(withKey: internalDeeplinkKey, presenter: presenter)
        } else if let integration = Integration(rawValue: notifiableUrl) {
            self.openIntegrationApp(forIntegration: integration)
        } else if let url = URL(string: notifiableUrl) {
            self.openUrlOnBrowser(url, presenter: presenter)
        }
    }
    
    // MARK: About You
    
    public func showAboutYouPage(presenter: UIViewController) {
        let aboutYouViewController = AboutYouViewController()
        let navigationController = UINavigationController(rootViewController: aboutYouViewController)
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true, completion: nil)
    }
    
    public func showAppsAndDevices(navigationController: UINavigationController, title: String) {
        let devicesViewController = DevicesIntegrationViewController(withTitle: title)
        navigationController.pushViewController(devicesViewController, animated: true)
    }
    
    public func showUserInfoPage(navigationController: UINavigationController,
                                 title: String,
                                 userInfoParameters: [UserInfoParameter]) {
        let userInfoViewController = UserInfoViewController(withTitle: title, userInfoParameters: userInfoParameters)
        navigationController.pushViewController(userInfoViewController, animated: true)
    }
    
    public func showPermissions(navigationController: UINavigationController, title: String) {
        let permissionViewController = PermissionViewController(withTitle: title)
        navigationController.pushViewController(permissionViewController, animated: true)
    }
    
    // MARK: Progress HUD
    
    public func pushProgressHUD() {
        if self.progressHudCount == 0 {
            SVProgressHUD.show()
        }
        self.progressHudCount += 1
    }
    
    public func popProgressHUD() {
        if self.progressHudCount > 0 {
            self.progressHudCount -= 1
            if self.progressHudCount == 0 {
                SVProgressHUD.dismiss()
            }
        }
    }
    
    // MARK: - Misc
    
    public func logOut() {
        self.repository.logOut()
        self.goToWelcome()
    }
    
    public func canOpenExternalUrl(_ url: URL) -> Bool {
        return UIApplication.shared.canOpenURL(url)
    }
    
    public func openSettings() {
        if let settings = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settings)
        }
    }
    
    public func openExternalUrl(_ url: URL) {
        guard self.canOpenExternalUrl(url) else {
            print("Cannot open given url: \(url)")
            return
        }
        UIApplication.shared.open(url)
    }
    
    public func openUrlOnBrowser(_ url: URL, presenter: UIViewController) {
        guard self.canOpenExternalUrl(url) else {
            print("Cannot open given url: \(url)")
            return
        }
        let viewController = SFSafariViewController(url: url)
        viewController.preferredControlTintColor = ColorPalette.color(withType: .primaryText)
        viewController.preferredBarTintColor = ColorPalette.color(withType: .secondary)
        presenter.present(viewController, animated: true, completion: nil)
    }
    
    public func openIntegrationApp(forIntegration intergration: Integration) {
        if self.canOpenExternalUrl(intergration.appSchemaUrl) {
            self.openExternalUrl(intergration.appSchemaUrl)
        } else {
            self.openExternalUrl(intergration.storeUrl)
        }
    }
    
    public func openWebView(withTitle title: String, url: URL, presenter: UIViewController) {
        let webViewViewController = WebViewViewController(withTitle: title, allowNavigation: true, url: url)
        let navigationViewController = UINavigationController(rootViewController: webViewViewController)
        navigationViewController.preventPopWithSwipe()
        presenter.present(navigationViewController, animated: true)
    }
    
    public func handleError(error: Error?,
                            presenter: UIViewController,
                            onDismiss: @escaping NotificationCallback = {},
                            onRetry: NotificationCallback? = nil,
                            dismissStyle: UIAlertAction.Style = .cancel) {
        SVProgressHUD.dismiss() // Safety dismiss
        guard let error = error else {
            presenter.showAlert(forError: nil, onDismiss: onDismiss, onRetry: onRetry, dismissStyle: dismissStyle)
            return
        }
        guard let alertError = error as? AlertError else {
            assertionFailure("Unexpected error type")
            presenter.showAlert(forError: nil, onDismiss: onDismiss, onRetry: onRetry, dismissStyle: dismissStyle)
            return
        }
        
        if false == self.handleUserNotLoggedError(error: error) {
            presenter.showAlert(forError: alertError, onDismiss: onDismiss, onRetry: onRetry, dismissStyle: dismissStyle)
        }
    }
    
    /// Check if the given error is a `Repository.userNotLoggedIn` error and, if so,
    /// perform a logout procedure.
    /// - Parameter error: the error to be checked
    /// - Returns: `true` if logout has been performed. `false` otherwise.
    public func handleUserNotLoggedError(error: Error?) -> Bool {
        if let error = error, case RepositoryError.userNotLoggedIn = error {
            print("Log out due to 'RepositoryError.userNotLoggedIn' error")
            self.logOut()
            return true
        } else {
            return false
        }
    }
    
    // MARK: - Study Info
    
    public func showInfoDetailPage(presenter: UIViewController, page: Page, isModal: Bool) {
        guard let navController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        
        let pageData = InfoDetailPageData(page: page, isModal: isModal)
        let pageViewController = InfoDetailPageViewController(withPageData: pageData)
        if isModal {
            presenter.modalPresentationStyle = .fullScreen
        }
        pageViewController.hidesBottomBarWhenPushed = true
        navController.pushViewController(pageViewController, animated: true)
    }
    
    // MARK: - Internal deeplink
    
    private func handleInternalDeeplink(withKey key: InternalDeeplinkKey, presenter: UIViewController) {
        switch key {
        case .feed: self.goToMainTab(tab: .feed, presenter: presenter)
        case .task: self.goToMainTab(tab: .task, presenter: presenter)
        case .userData: self.goToMainTab(tab: .userData, presenter: presenter)
        case .studyInfo: self.goToMainTab(tab: .studyInfo, presenter: presenter)
        case .aboutYou: self.showAboutYouPage(presenter: presenter)
        case .faq:
            // TODO: Show FAQ
            print("AppNavigator - TODO: Show FAQ")
        case .rewards:
            // TODO: Show Rewards
            print("AppNavigator - TODO: Show Rewards")
        case .contacts:
            // TODO: Show Contacts
            print("AppNavigator - TODO: Show Contacts")
        }
    }
    
    private func goToMainTab(tab: MainTab, presenter: UIViewController) {
        guard let tabBarController = presenter.tabBarController else {
            print("AppNavigator - Missing tab bar controller")
            return
        }
        tabBarController.selectedIndex = tab.rawValue
    }
}

// MARK: - DeeplinkManagerDelegate

extension AppNavigator: DeeplinkManagerDelegate {
    func handleDeeplink(_ deeplink: Deeplink) -> Bool {
        guard self.setupCompleted else {
            // If App Setup is still in progress, the deeplink
            // will be handled upon setup completion
            return false
        }
        
        guard self.repository.isLoggedIn, self.repository.currentUser?.isOnboardingCompleted ?? false else {
            // Currently no deeplink are expected to do anything if user is logged out or
            // has not completed the onboarding yet.
            return true
        }
        
        switch deeplink {
        case .openTask, .openUrl:
            if self.isTaskInProgress == false {
                self.goHome()
                return false
            }
        case .openIntegrationApp(let integration):
            self.openIntegrationApp(forIntegration: integration)
        }
        return true
    }
}

// MARK: - Extension(UIViewController)

extension UIViewController {
    func showAlert(forError error: Error?,
                   onDismiss: @escaping NotificationCallback = {},
                   onRetry: NotificationCallback? = nil,
                   dismissStyle: UIAlertAction.Style = .cancel) {
        var actions: [UIAlertAction] = []
        let dismissAction = UIAlertAction(title: StringsProvider.string(forKey: .errorButtonClose),
                                          style: dismissStyle,
                                          handler: { _ in onDismiss() })
        actions.append(dismissAction)
        if let onRetry = onRetry {
            let retryAction = UIAlertAction(title: StringsProvider.string(forKey: .errorButtonRetry),
                                            style: .default,
                                            handler: { _ in onRetry() })
            actions.append(retryAction)
        }
        self.showAlert(withTitle: StringsProvider.string(forKey: .errorTitleDefault),
                       message: error?.localizedDescription ?? StringsProvider.string(forKey: .errorMessageDefault),
                       actions: actions,
                       tintColor: ColorPalette.color(withType: .primary))
    }
    
    func showAlert(withTitle title: String,
                   message: String,
                   dismissButtonText: String,
                   onDismiss: @escaping NotificationCallback = {}) {
        let dismissAction = UIAlertAction(title: dismissButtonText,
                                          style: .default,
                                          handler: { _ in onDismiss() })
        self.showAlert(withTitle: title,
                       message: message,
                       actions: [dismissAction],
                       tintColor: ColorPalette.color(withType: .primary))
    }
}
