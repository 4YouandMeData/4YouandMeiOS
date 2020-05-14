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
        self.window.rootViewController = SetupViewController()
    }
    
    func showSetupCompleted() {
        self.onStartup()
    }
    
    // MARK: - Top level
    
    func onStartup() {
        if self.repository.isLoggedIn {
            // TODO: Show user step (screening questions, consent, home)
            assertionFailure("Log in behaviour not implemented")
        } else {
            self.goToWelcome()
        }
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
        guard let welcomeViewController = navigationController.viewControllers.first(where: { $0 is WelcomeViewController }) else {
            assertionFailure("Missing WelcomeViewController in navigation stack")
            return
        }
        navigationController.popToViewController(welcomeViewController, animated: true)
    }
    
    // MARK: - Login
    
    public func showLogin(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(PhoneVerificationViewController(), animated: true)
    }
    
    public func showCodeValidation(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        navigationController.pushViewController(CodeValidationViewController(), animated: true)
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
//        guard let navigationController = presenter.navigationController else {
//            assertionFailure("Missing UINavigationController")
//            return
//        }
        // TODO: Show intro video
        print("TODO: Show intro video")
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
        self.goToWelcome()
    }
    
    public func openOnExternalBrowser(url: URL) {
        UIApplication.shared.open(url)
    }
    
    public func handleError(error: Error?, presenter: UIViewController, handleLogout: Bool = true) {
        SVProgressHUD.dismiss() // Safety dismiss
        guard let error = error else {
            presenter.showGenericErrorAlert()
            return
        }
        
        if let repositoryError = error as? RepositoryError {
            switch repositoryError {
            case .userNotLoggedIn:
                if handleLogout {
                    self.logOut()
                } else {
                    presenter.showAlert(forError: RepositoryError.genericError)
                }
            default:
                presenter.showAlert(forError: error)
            }
        } else {
            presenter.showAlert(forError: error)
        }
    }
    
    // MARK: - Private Methods
    
    private func openWebView(withTitle title: String, url: URL, presenter: UIViewController) {
        let wevViewViewController = WebViewViewController(withTitle: title, allowNavigation: true, url: url)
        let navigationViewController = UINavigationController(rootViewController: wevViewViewController)
        navigationViewController.preventPopWithSwipe()
        presenter.present(navigationViewController, animated: true)
    }
}

// MARK: - Extension(UIViewController)

fileprivate extension UIViewController {
    func showAlert(forError error: Error, completion: @escaping (() -> Void) = {}) {
        self.showAlert(withTitle: StringsProvider.string(forKey: .errorTitleDefault),
                       message: error.localizedDescription,
                       completion: completion)
    }
    
    func showGenericErrorAlert() {
        self.showAlert(withTitle: StringsProvider.string(forKey: .errorTitleDefault),
                       message: StringsProvider.string(forKey: .errorMessageDefault),
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
