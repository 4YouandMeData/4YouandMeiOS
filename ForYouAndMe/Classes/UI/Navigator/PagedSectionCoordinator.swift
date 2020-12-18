//
//  PagedSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import Foundation

protocol PagedSectionCoordinator: PageCoordinator {
    var navigationController: UINavigationController { get }
    var pages: [Page] { get }
    var isOnboarding: Bool { get }
    
    func showPage(_ page: Page)
    func showLinkedPage(forPageRef pageRef: PageRef)
    func showModalPage(forPageRef pageRef: PageRef)
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool
    func onUnhandledPrimaryButtonNavigation(page: Page)
    
    func performCustomSecondaryButtonNavigation(page: Page) -> Bool
    func onUnhandledSecondaryButtonNavigation(page: Page)
}

extension PagedSectionCoordinator {
    
    func showPage(_ page: Page) {
        let infoPageData = InfoPageData.createInfoPageData(withPage: page, isOnboarding: self.isOnboarding)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    func showResultPage(_ page: Page) {
        let infoPageData = InfoPageData.createResultPageData(withPage: page)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    func showLinkedPage(forPageRef pageRef: PageRef) {
        let previousController = self.navigationController.viewControllers.reversed().first { viewController -> Bool in
            if let pageProvider = viewController as? PageProvider,
                pageProvider.page.id == pageRef.id {
                return true
            } else {
                return false
            }
        }
        if let previousController = previousController {
            self.navigationController.popToViewController(previousController, animated: true)
        } else {
            guard let nextPage = self.pages.getPage(forPageRef: pageRef) else {
                assertionFailure("Missing page for page ref")
                return
            }
            self.showPage(nextPage)
        }
    }
    
    func showModalPage(forPageRef pageRef: PageRef) {
        guard let modalPage = self.pages.getPage(forPageRef: pageRef) else {
            assertionFailure("Missing page for page ref")
            return
        }
        let infoDetailPageData = InfoDetailPageData(page: modalPage, isModal: true)
        let viewController = InfoDetailPageViewController(withPageData: infoDetailPageData)
        let navigationViewController = UINavigationController(rootViewController: viewController)
        navigationViewController.preventPopWithSwipe()
        self.navigationController.present(navigationViewController, animated: true)
    }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        assertionFailure("Missing action for primary button pressed!")
    }
    
    func performCustomSecondaryButtonNavigation(page: Page) -> Bool {
        return false
    }
    
    func onUnhandledSecondaryButtonNavigation(page: Page) {
        assertionFailure("Missing action for secondary button pressed!")
    }
    
    // MARK: - PageCoordinator
    
    func onPagePrimaryButtonPressed(page: Page) {
        let handled = self.performCustomPrimaryButtonNavigation(page: page)
        if false == handled {
            if let pageRef = page.buttonFirstPage {
                self.showLinkedPage(forPageRef: pageRef)
            } else {
                self.onUnhandledPrimaryButtonNavigation(page: page)
            }
        }
    }
    
    func onPageSecondaryButtonPressed(page: Page) {
        let handled = self.performCustomSecondaryButtonNavigation(page: page)
        if false == handled {
            if let pageRef = page.buttonSecondPage {
                self.showLinkedPage(forPageRef: pageRef)
            } else {
                self.onUnhandledSecondaryButtonNavigation(page: page)
            }
        }
    }
    
    func onLinkedPageButtonPressed(modalPageRef: PageRef) {
        self.showModalPage(forPageRef: modalPageRef)
    }
}
