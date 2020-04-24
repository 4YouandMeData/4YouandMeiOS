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

class AppNavigator {
    
    private var progressHudCount = 0
    
    private let repository: Repository
    private let window: UIWindow
    private let disposeBag = DisposeBag()
    
    init(withRepository repository: Repository, window: UIWindow) {
        self.repository = repository
        self.window = window
        
        // Needed to block user interaction!! :S
        SVProgressHUD.setDefaultMaskType(.black)
    }
    
    // MARK: - Initialization
    
    func showSetupScreen() {
        self.window.rootViewController = SetupViewController()
        SVProgressHUD.showProgress(0)
    }
    
    func showSetupProgress(progress: Float) {
        SVProgressHUD.showProgress(progress)
    }
    
    func showSetupError(error: Error) {
        if let presenter = self.window.rootViewController {
            self.handleError(error: error, presenter: presenter)
        }
    }
    
    func showSetupCompleted() {
        SVProgressHUD.dismiss()
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
        self.window.rootViewController = WelcomeViewController()
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
        // TODO: Implement logout
        assertionFailure("Log out not implemented")
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
}

// MARK: - Extension(UIViewController)

fileprivate extension UIViewController {
    func showAlert(forError error: Error, completion: @escaping (() -> Void) = {}) {
        self.showAlert(withTitle: "GENERIC_ERROR_TITLE".localized, message: error.localizedDescription, completion: completion)
    }
    
    func showGenericErrorAlert() {
        self.showAlert(withTitle: "GENERIC_ERROR_TITLE".localized, message: "GENERIC_ERROR_DEFAULT".localized, completion: {})
    }
}
