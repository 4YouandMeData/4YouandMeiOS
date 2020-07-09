//
//  WearablesSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

enum WearablesSpecialLinkBehaviour: CaseIterable {
    static var allCases: [WearablesSpecialLinkBehaviour] {
        return [.download(app: nil), .open(app: nil)]
    }
    
    case download(app: WearableApp?)
    case open(app: WearableApp?)
    
    var keyword: String {
        switch self {
        case .download: return "download"
        case .open: return "open"
        }
    }
}

class WearablesSectionCoordinator {
    
    public unowned var navigationController: UINavigationController
    
    private let navigator: AppNavigator
    
    private let sectionData: WearablesSection
    private let completionCallback: NavigationControllerCallback
    
    init(withSectionData sectionData: WearablesSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.navigator = Services.shared.navigator
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        return WearablePageViewController(withPage: self.sectionData.welcomePage, coordinator: self, backwardNavigation: false)
    }
}

extension WearablesSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func showPage(_ page: Page, isOnboarding: Bool) {
        let viewController = WearablePageViewController(withPage: page, coordinator: self, backwardNavigation: true)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController)
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        if let successPage = self.sectionData.successPage {
            self.showPage(successPage, isOnboarding: true)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension WearablesSectionCoordinator: WearablePageCoordinator {
    func onWearablePageExternalLinkButtonPressed(page: Page) {
        guard let externalLinkUrl = page.externalLinkUrl else {
            assertionFailure("Missing expected external link url")
            return
        }
        let viewController = WearableLoginViewController(withTitle: "",
                                                         url: externalLinkUrl,
                                                         onLoginSuccessCallback: { loginViewController in
                                                            loginViewController.dismiss(animated: true, completion: { [weak self] in
                                                                self?.onPagePrimaryButtonPressed(page: page)
                                                            })
        },
                                                         onLoginFailureCallback: { loginViewController in
                                                            loginViewController.dismiss(animated: true, completion: nil)
        })
        let navigationViewController = UINavigationController(rootViewController: viewController)
        navigationViewController.preventPopWithSwipe()
        self.navigationController.present(navigationViewController, animated: true, completion: nil)
    }
    
    func onWearablePageSpecialLinkButtonPressed(page: Page) {
        guard let specialLinkBehaviour = page.wearablesSpecialLinkBehaviour else {
            assertionFailure("Missing expected special link behaviour")
            return
        }
        
        switch specialLinkBehaviour {
        case .download(let app):
            guard let app = app else {
                assertionFailure("Missing app for download behaviour")
                return
            }
            self.navigator.openExternalUrl(app.storeUrl)
        case .open(let app):
            guard let app = app else {
                assertionFailure("Missing app for open behaviour")
                return
            }
            if self.navigator.canOpenExternalUrl(app.appSchemaUrl) {
                self.navigator.openExternalUrl(app.appSchemaUrl)
            } else {
                self.navigator.openExternalUrl(app.storeUrl)
            }
        }
    }
}
