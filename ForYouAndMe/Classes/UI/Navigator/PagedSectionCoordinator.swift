//
//  PagedSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import Foundation

protocol PagedSectionCoordinator: InfoPageCoordinator {
    var navigationController: UINavigationController { get }
    var pages: [InfoPage] { get }
    
    func showInfoPage(_ page: InfoPage, isOnboarding: Bool)
    func handleShowNextPage(forCurrentPage page: InfoPage, isOnboarding: Bool) -> Bool
}

extension PagedSectionCoordinator {
    func showInfoPage(_ page: InfoPage, isOnboarding: Bool) {
        let infoPageData = InfoPageData(page: page,
                                        addAbortOnboardingButton: isOnboarding,
                                        allowBackwardNavigation: true,
                                        bodyTextAlignment: .left)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    func handleShowNextPage(forCurrentPage page: InfoPage, isOnboarding: Bool) -> Bool {
        if let nextPageRef = page.buttonFirstPage {
            guard let nextPage = self.pages.getFirstNextPage(forPageRef: nextPageRef) else {
                assertionFailure("Missing page for page ref")
                return false
            }
            self.showInfoPage(nextPage, isOnboarding: isOnboarding)
            return true
        }
        return false
    }
}
