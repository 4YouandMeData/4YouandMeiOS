//
//  IntegrationSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

enum IntegrationSpecialLinkBehaviour: CaseIterable {
    static var allCases: [IntegrationSpecialLinkBehaviour] {
        return [.download(app: nil), .open(app: nil)]
    }
    
    case download(app: Integration?)
    case open(app: Integration?)
    
    var keyword: String {
        switch self {
        case .download: return "download"
        case .open: return "open"
        }
    }
}

class IntegrationSectionCoordinator {
    
    public unowned var navigationController: UINavigationController
    
    private let navigator: AppNavigator
    
    private let sectionData: IntegrationSection
    private let completionCallback: NavigationControllerCallback
    
    init(withSectionData sectionData: IntegrationSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.navigator = Services.shared.navigator
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        return IntegrationPageViewController(withPage: self.sectionData.welcomePage, coordinator: self, backwardNavigation: false)
    }
}

extension IntegrationSectionCoordinator: PagedSectionCoordinator {
    
    var isOnboarding: Bool { true }
    var pages: [Page] { self.sectionData.pages }
    
    func showPage(_ page: Page) {
        let viewController = IntegrationPageViewController(withPage: page, coordinator: self, backwardNavigation: true)
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
            self.showPage(successPage)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension IntegrationSectionCoordinator: IntegrationPageCoordinator {
    func onIntegrationPageExternalLinkButtonPressed(page: Page) {
        guard let externalLinkUrl = page.externalLinkUrl else {
            assertionFailure("Missing expected external link url")
            return
        }
        let viewController = ReactiveAuthWebViewController(withTitle: "",
                                                           url: externalLinkUrl,
                                                           allowBackwardNavigation: true,
                                                           onSuccessCallback: { loginViewController in
                                                            loginViewController.dismiss(animated: true, completion: { [weak self] in
                                                                self?.onPagePrimaryButtonPressed(page: page)
                                                            })
                                                           },
                                                           onFailureCallback: { loginViewController in
                                                            loginViewController.dismiss(animated: true, completion: nil)
                                                           })
        let navigationViewController = UINavigationController(rootViewController: viewController)
        navigationViewController.preventPopWithSwipe()
        self.navigationController.present(navigationViewController, animated: true, completion: nil)
    }
    
    func onIntegrationPageSpecialLinkButtonPressed(page: Page) {
        guard let specialLinkBehaviour = page.integrationSpecialLinkBehaviour else {
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
            self.navigator.openIntegrationApp(forIntegration: app)
        }
    }
}
