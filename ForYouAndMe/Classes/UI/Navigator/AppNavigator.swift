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
            case .consentUserDataSection: self.startUserContentDataSection(navigationController: testNavigationViewController)
            }
            return
        }
        #endif
        
        if self.repository.isLoggedIn {
            // TODO: Check if onboarding is completed
            print("TODO: Check if onboarding is completed")
            let onboardingCompleted = false
            if onboardingCompleted {
                // TODO: Implement Home
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
            let coordinator = ScreeningCoordinator(withSectionData: section,
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
            let coordinator = InformedConsentCoordinator(withSectionData: section,
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
            let coordinator = ConsentCoordinator(withSectionData: section,
                                                 navigationController: navigationController,
                                                 completionCallback: completionCallback)
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Opt-In
    
    public func startOptInSection(navigationController: UINavigationController) {
        // TODO: Implement Opt In-section
        print("TODO: Implement Opt In-section")
        self.startUserContentDataSection(navigationController: navigationController)
    }
    
    // MARK: Consent User Data
    
    public func startUserContentDataSection(navigationController: UINavigationController) {
        navigationController.loadViewForRequest(self.repository.getUserConsentSection()) { section -> UIViewController in
            let completionCallback: NavigationControllerCallback = { [weak self] navigationController in
                self?.startDownloadAppsSection(navigationController: navigationController)
            }
            let coordinator = ConsentUserDataCoordinator(withSectionData: section,
                                                         navigationController: navigationController,
                                                         completionCallback: completionCallback)
            return coordinator.getStartingPage()
        }
    }
    
    // MARK: Download Apps
    
    public func startDownloadAppsSection(navigationController: UINavigationController) {
        // TODO: Start Download Apps section
        navigationController.showAlert(withTitle: "Work in progress", message: "Download Apps section coming soon")
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
    
    public func openOnExternalBrowser(url: URL) {
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
                       tintColor: ColorPalette.color(withType: .primary),
                       completion: completion)
    }
    
    func showGenericErrorAlert() {
        self.showAlert(withTitle: StringsProvider.string(forKey: .errorTitleDefault),
                       message: StringsProvider.string(forKey: .errorMessageDefault),
                       tintColor: ColorPalette.color(withType: .primary),
                       completion: {})
    }
    
    func showAlert(withTitle title: String, message: String) {
        self.showAlert(withTitle: title,
                       message: message,
                       tintColor: ColorPalette.color(withType: .primary),
                       completion: {})
    }
}

// MARK: - Extension(UINavigationController)

fileprivate extension UINavigationController {
    func preventPopWithSwipe() {
        if self.responds(to: #selector(getter: UINavigationController.interactivePopGestureRecognizer)) {
            self.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}
