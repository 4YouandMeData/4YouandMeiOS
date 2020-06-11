//
//  InformedConsentCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/06/2020.
//

import Foundation

class InformedConsentCoordinator: PagedSectionCoordinator {
    
    public unowned var navigationController: UINavigationController
    
    var pages: [InfoPage] { self.sectionData.pages }
    
    private let sectionData: InformedConsentSection
    private let completionCallback: NavigationControllerCallback
    
    init(withSectionData sectionData: InformedConsentSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        let infoPageData = InfoPageData.createWelcomePageData(withinfoPage: self.sectionData.welcomePage)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }
    
    // MARK: - Private Methods
    
    private func showQuestions() {
        if self.sectionData.questions.count > 0 {
            // TODO: Add Informed Consent questions
            self.navigationController.showAlert(withTitle: "Work in progress", message: "Informed Consent questions coming soon")
        } else {
            self.completionCallback(self.navigationController)
        }
    }
    
    private func showSuccess() {
        guard let successPage = self.sectionData.successPage else {
            assertionFailure("Missing expected success page")
            return
        }
        let infoPageData = InfoPageData.createResultPageData(withinfoPage: successPage)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func showFailure() {
        guard let failurePage = self.sectionData.failurePage else {
            assertionFailure("Missing expected failure page")
            return
        }
        let infoPageData = InfoPageData(page: failurePage,
                                        addAbortOnboardingButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .center,
                                        bottomViewStyle: .vertical(backButton: true))
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
}

extension InformedConsentCoordinator: InfoPageCoordinator {
    func onInfoPagePrimaryButtonPressed(pageData: InfoPageData) {
        switch pageData.page.id {
        case self.sectionData.successPage?.id:
            self.completionCallback(self.navigationController)
        default:
            if let pageRef = pageData.page.buttonFirstPage {
                self.showLinkedPage(forPageRef: pageRef, isOnboarding: true)
            } else {
                self.showQuestions()
            }
        }
    }
    
    func onInfoPageSecondaryButtonPressed(pageData: InfoPageData) {
        guard let pageRef = pageData.page.buttonSecondPage else {
            assertionFailure("Missing action for secondary button pressed!")
            return
        }
        self.showLinkedPage(forPageRef: pageRef, isOnboarding: true)
    }
}
