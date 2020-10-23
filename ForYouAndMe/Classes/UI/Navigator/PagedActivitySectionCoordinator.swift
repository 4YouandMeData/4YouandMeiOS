//
//  PagedActivitySectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/10/2020.
//

import UIKit

protocol PagedActivitySectionCoordinator: ActivitySectionCoordinator, PagedSectionCoordinator {
    var internalNavigationController: UINavigationController? { get set }
    var activity: Activity { get }
    var coreViewController: UIViewController? { get }
}

extension PagedActivitySectionCoordinator {
    var pages: [Page] { self.activity.pages }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.activity.successPage?.id == page.id {
            self.completionCallback()
            return true
        }
        return false
    }
    
    func performCustomSecondaryButtonNavigation(page: Page) -> Bool {
        if self.activity.welcomePage.id == page.id {
            self.delayActivity()
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        guard let coreViewController = self.coreViewController else {
            assertionFailure("Missing Core View Controller")
            if let activityPresenter = self.activityPresenter {
                self.navigator.handleError(error: nil, presenter: activityPresenter)
            }
            return
        }
        self.navigationController.pushViewController(coreViewController, animated: true)
    }
    
    var navigationController: UINavigationController {
        guard let navigationController = self.internalNavigationController else {
            assertionFailure("Missing navigation controller")
            return UINavigationController()
        }
        return navigationController
    }
    
    func getStartingPage() -> UIViewController {
        let data = InfoPageData(page: self.activity.welcomePage,
                                addAbortOnboardingButton: false,
                                addCloseButton: true,
                                allowBackwardNavigation: false,
                                bodyTextAlignment: .left,
                                bottomViewStyle: .horizontal,
                                customImageHeight: nil)
        
        let welcomeViewController = InfoPageViewController(withPageData: data,
                                                          coordinator: self)
        let navigationController = UINavigationController(rootViewController: welcomeViewController)
        self.internalNavigationController = navigationController
        return navigationController
    }
    
    func showSuccessPage() {
        if let successPage = self.activity.successPage {
            let data = InfoPageData.createResultPageData(withPage: successPage)
            let successViewController = InfoPageViewController(withPageData: data,
                                                              coordinator: self)
            self.navigationController.pushViewController(successViewController, animated: true)
        } else {
            self.completionCallback()
        }
    }
}
