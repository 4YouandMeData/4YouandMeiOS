//
//  WearablesSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

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
        return WearablePageViewController(withPage: self.sectionData.welcomePage, coordinator: self)
    }
}

extension WearablesSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func showPage(_ page: Page, isOnboarding: Bool) {
        let viewController = WearablePageViewController(withPage: page, coordinator: self)
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
        // TODO: Implement Wearable login
        print("WearablesSectionCoordinator - TODO: Open url \(externalLinkUrl) on webview")
        self.navigationController.showAlert(withTitle: "Work in progress", message: "Wearable login coming soon", closeButtonText: "Ok")
//        self.navigator.openWebView(withTitle: page.title, url: externalLinkUrl, presenter: self.navigationController)
    }
    func onWearablePageSpecialLinkButtonPressed(page: Page) {
        guard let specialLinkValue = page.specialLinkValue else {
            assertionFailure("Missing expected special link url")
            return
        }
        if self.navigator.canOpenExternalUrl(specialLinkValue) {
            self.navigator.openExternalUrl(specialLinkValue)
        } else {
            self.navigationController.showAlert(withTitle: page.title,
                                                message: "You did not downloaded the app. Please download the app and try again",
                                                closeButtonText: StringsProvider.string(forKey: .errorButtonClose))
        }
    }
}
