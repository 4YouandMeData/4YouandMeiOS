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
    func showLinkedPage(forPageRef pageRef: InfoPageRef, isOnboarding: Bool)
}

extension PagedSectionCoordinator {
    func showInfoPage(_ page: InfoPage, isOnboarding: Bool) {
        let infoPageData = InfoPageData.createInfoPageData(withinfoPage: page, isOnboarding: isOnboarding)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    func showLinkedPage(forPageRef pageRef: InfoPageRef, isOnboarding: Bool) {
        let previousController = self.navigationController.viewControllers.reversed().first { viewController -> Bool in
            if let infoPageViewController = viewController as? InfoPageViewController,
                infoPageViewController.pageData.page.id == pageRef.id {
                return true
            } else {
                return false
            }
        }
        if let previousController = previousController {
            self.navigationController.popToViewController(previousController, animated: true)
        } else {
            guard let nextPage = self.pages.getFirstNextPage(forPageRef: pageRef) else {
                assertionFailure("Missing page for page ref")
                return
            }
            self.showInfoPage(nextPage, isOnboarding: isOnboarding)
        }
    }
}
