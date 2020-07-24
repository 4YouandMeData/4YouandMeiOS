//
//  AppNavigator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import SVProgressHUD

class AppNavigator {
    
    private var progressHudCount = 0
    
    private let repository: Repository
    private let window: UIWindow
    
    private var currentTaskCoordinator: TaskSectionCoordinator?
    
    init(withRepository repository: Repository, window: UIWindow) {
        self.repository = repository
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
            case .screeningSection: self.startScreeningSection(navigationController: testNavigationViewController)
            case .informedConsentSection: self.startInformedConsentSection(navigationController: testNavigationViewController)
            case .consentSection: self.startConsentSection(navigationController: testNavigationViewController)
            case .optInSection: self.startOptInSection(navigationController: testNavigationViewController)
            case .consentUserDataSection: self.startUserContentDataSection(navigationController: testNavigationViewController)
            case .wearablesSection: self.startWearablesSection(navigationController: testNavigationViewController)
            }
            return
        }
        #endif
        
        if self.repository.isLoggedIn {
            // TODO: Check if onboarding is completed
            print("TODO: Check if onboarding is completed")
            var onboardingCompleted = false
            #if DEBUG
            if let testOnboardingCompleted = Constants.Test.OnboardingCompleted {
                onboardingCompleted = testOnboardingCompleted
            }
            #endif
            if onboardingCompleted {
                self.goHome()
            } else {
                // If onboarding is not completed, log out (restart from the very beginning)
                self.logOut()
            }
        } else {
            self.goToWelcome()
        }
    }
    
    public func abortOnboardingWithWarning(presenter: UIViewController) {
        presenter.showAlert(withTitle: StringsProvider.string(forKey: .onboardingAbortTitle),
                            message: StringsProvider.string(forKey: .onboardingAbortMessage),
                            cancelText: StringsProvider.string(forKey: .onboardingAbortCancel),
                            confirmText: StringsProvider.string(forKey: .onboardingAbortConfirm),
                            tintColor: ColorPalette.color(withType: .primary),
                            confirm: { [weak self] in
                                self?.abortOnboarding()
        })
    }
    
    public func abortOnboarding() {
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
        self.openWebView(withTitle: "", url: url, presenter: presenter)
    }
    
    public func showTermsOfService(presenter: UIViewController) {
        guard let url = URL(string: StringsProvider.string(forKey: .urlTermsOfService)) else {
            assertionFailure("Invalid Url for terms of service")
            return
        }
        self.openWebView(withTitle: "", url: url, presenter: presenter)
    }
    
    // MARK: Intro Video
    
    public func showIntroVideo(presenter: UIViewController) {
        // TODO: Show intro video
        print("TODO: Show intro video")
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
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Consent
    
    public func startConsentSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getConsentSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.startOptInSection(navigationController: navigationController)
            }
            let coordinator = ConsentSectionCoordinator(withSectionData: section,
                                                        navigationController: navigationController,
                                                        completionCallback: completionCallback)
            return coordinator.getStartingPage()
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
                self?.startWearablesSection(navigationController: navigationController)
            }
            let coordinator = ConsentUserDataSectionCoordinator(withSectionData: section,
                                                                navigationController: navigationController,
                                                                completionCallback: completionCallback)
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Wearables
    
    public func startWearablesSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getWearablesSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.goHome()
            }
            let coordinator = WearablesSectionCoordinator(withSectionData: section,
                                                         navigationController: navigationController,
                                                         completionCallback: completionCallback)
            return coordinator.getStartingPage()
        }
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
        
        let feedViewController = FeedViewController()
        let feedNavigationController = UINavigationController(rootViewController: feedViewController)
        feedNavigationController.preventPopWithSwipe()
        feedNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabFeed)
        feedNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabFeed)
        feedNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
        viewControllers.append(feedNavigationController)
        
        let taskViewController = TaskViewController()
        let taskNavigationController = UINavigationController(rootViewController: taskViewController)
        taskNavigationController.preventPopWithSwipe()
        taskNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabTask)
        taskNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabTask)
        taskNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
        viewControllers.append(taskNavigationController)
        
        let userDataViewController = UserDataViewController()
        let userDataNavigationController = UINavigationController(rootViewController: userDataViewController)
        userDataNavigationController.preventPopWithSwipe()
        userDataNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabUserData)
        userDataNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabUserData)
        userDataNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
        viewControllers.append(userDataNavigationController)
        
        let studyInfoViewController = StudyInfoViewController()
        let studyInfoNavigationController = UINavigationController(rootViewController: studyInfoViewController)
        studyInfoNavigationController.preventPopWithSwipe()
        studyInfoNavigationController.tabBarItem.image = ImagePalette.templateImage(withName: .tabStudyInfo)
        studyInfoNavigationController.tabBarItem.title = StringsProvider.string(forKey: .tabStudyInfo)
        studyInfoNavigationController.tabBarItem.setTitleTextAttributes([.font: titleFont], for: .normal)
        viewControllers.append(studyInfoNavigationController)
        
        tabBarController.viewControllers = viewControllers
        tabBarController.selectedIndex = viewControllers.firstIndex(of: feedViewController) ?? 0
        self.window.rootViewController = tabBarController
    }
    
    public func switchToFeedTab(presenter: UIViewController) {
        guard let tabBarController = presenter.tabBarController else { return }
        guard let feedViewControllerIndex = tabBarController.viewControllers?.firstIndex(where: { viewController in
            (viewController as? UINavigationController)?.viewControllers.first is FeedViewController
        }) else { return }
        tabBarController.selectedIndex = feedViewControllerIndex
    }
    
    // MARK: Task
    
    public func startTaskSection(taskType: TaskType, presenter: UIViewController) {
        let completionCallback: ViewControllerCallback = { [weak self] presenter in
            guard let self = self else { return }
            presenter.dismiss(animated: true, completion: nil)
            self.currentTaskCoordinator = nil
        }
        let coordinator = TaskSectionCoordinator(withTaskType: taskType,
                                                 presenter: presenter,
                                                 completionCallback: completionCallback)
        let startingPage = coordinator.getStartingPage()
        presenter.present(startingPage, animated: true, completion: nil)
        self.currentTaskCoordinator = coordinator
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
    
    public func openExternalUrl(_ url: URL) {
        guard self.canOpenExternalUrl(url) else {
            print("Cannot open given url: \(url)")
            return
        }
        UIApplication.shared.open(url)
    }
    
    public func openWebView(withTitle title: String, url: URL, presenter: UIViewController) {
        let wevViewViewController = WebViewViewController(withTitle: title, allowNavigation: true, url: url)
        let navigationViewController = UINavigationController(rootViewController: wevViewViewController)
        navigationViewController.preventPopWithSwipe()
        presenter.present(navigationViewController, animated: true)
    }
    
    public func handleError(error: Error?, presenter: UIViewController) {
        SVProgressHUD.dismiss() // Safety dismiss
        guard let error = error else {
            presenter.showGenericErrorAlert()
            return
        }
        guard let repositoryError = error as? RepositoryError else {
            assertionFailure("Unexpected error type")
            presenter.showGenericErrorAlert()
            return
        }
        
        if false == self.handleUserNotLoggedError(error: error) {
            presenter.showAlert(forError: repositoryError)
        }
    }
    
    /// Check if the given error is a `Repository.userNotLoggedIn` error and, if so,
    /// perform a logout procedure.
    /// - Parameter error: the error to be checked
    /// - Returns: `true` if logout has been performed. `false` otherwise.
    public func handleUserNotLoggedError(error: Error?) -> Bool {
        if let error = error, case RepositoryError.userNotLoggedIn = error {
            print("Log out due to 'RepositoryError.userNotLoggedIn' error")
            // TODO: Show a user friendly popup to explain the user that he must login again.
            self.logOut()
            return true
        } else {
            return false
        }
    }
}

// MARK: - Extension(UIViewController)

extension UIViewController {
    func showAlert(forError error: Error, completion: @escaping (() -> Void) = {}) {
        self.showAlert(withTitle: StringsProvider.string(forKey: .errorTitleDefault),
                       message: error.localizedDescription,
                       confirmButtonText: StringsProvider.string(forKey: .errorButtonClose),
                       tintColor: ColorPalette.color(withType: .primary),
                       completion: completion)
    }
    
    func showGenericErrorAlert() {
        self.showAlert(withTitle: StringsProvider.string(forKey: .errorTitleDefault),
                       message: StringsProvider.string(forKey: .errorMessageDefault),
                       confirmButtonText: StringsProvider.string(forKey: .errorButtonClose),
                       tintColor: ColorPalette.color(withType: .primary),
                       completion: {})
    }
    
    func showAlert(withTitle title: String, message: String, closeButtonText: String) {
        self.showAlert(withTitle: title,
                       message: message,
                       confirmButtonText: closeButtonText,
                       tintColor: ColorPalette.color(withType: .primary),
                       completion: {})
    }
}
