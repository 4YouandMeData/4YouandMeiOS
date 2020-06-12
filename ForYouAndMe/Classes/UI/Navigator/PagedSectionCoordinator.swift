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
    
    func performCustomPrimaryButtonNavigation(page: InfoPage) -> Bool
    func onUnhandledPrimaryButtonNavigation(page: InfoPage)
    
    func performCustomSecondaryButtonNavigation(page: InfoPage) -> Bool
    func onUnhandledSecondaryButtonNavigation(page: InfoPage)
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
    
    func performCustomPrimaryButtonNavigation(page: InfoPage) -> Bool {
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: InfoPage) {
        assertionFailure("Missing action for primary button pressed!")
    }
    
    func performCustomSecondaryButtonNavigation(page: InfoPage) -> Bool {
        return false
    }
    
    func onUnhandledSecondaryButtonNavigation(page: InfoPage) {
        assertionFailure("Missing action for secondary button pressed!")
    }
    
    // MARK: - InfoPageCoordinator
    
    func onInfoPagePrimaryButtonPressed(pageData: InfoPageData) {
        let handled = self.performCustomPrimaryButtonNavigation(page: pageData.page)
        if false == handled {
            if let pageRef = pageData.page.buttonFirstPage {
                self.showLinkedPage(forPageRef: pageRef, isOnboarding: true)
            } else {
                self.onUnhandledPrimaryButtonNavigation(page: pageData.page)
            }
        }
    }
    
    func onInfoPageSecondaryButtonPressed(pageData: InfoPageData) {
        let handled = self.performCustomSecondaryButtonNavigation(page: pageData.page)
        if false == handled {
            if let pageRef = pageData.page.buttonSecondPage {
                self.showLinkedPage(forPageRef: pageRef, isOnboarding: true)
            } else {
                self.onUnhandledSecondaryButtonNavigation(page: pageData.page)
            }
        }
    }
}
