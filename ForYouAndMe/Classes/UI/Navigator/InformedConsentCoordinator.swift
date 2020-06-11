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
        let infoPageData = InfoPageData(page: self.sectionData.welcomePage,
                                        addAbortOnboardingButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .left)
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
        let infoPageData = InfoPageData(page: successPage,
                                        addAbortOnboardingButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .center)
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
                                        bodyTextAlignment: .center)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func popBackToQuestions() {
        // TODO: pop to the first questions
        print("InformedConsentCoordinator - TODO: pop to the first questions")
    }
}

extension InformedConsentCoordinator: InfoPageCoordinator {
    func onInfoPageConfirm(pageData: InfoPageData) {
        switch pageData.page.id {
        case self.sectionData.successPage?.id:
            self.completionCallback(self.navigationController)
        case self.sectionData.failurePage?.id:
            self.popBackToQuestions()
        default:
            if false == self.handleShowNextPage(forCurrentPage: pageData.page, isOnboarding: true) {
                self.showQuestions()
            }
        }
    }
}
