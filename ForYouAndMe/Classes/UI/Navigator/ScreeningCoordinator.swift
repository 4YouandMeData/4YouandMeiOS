//
//  ScreeningCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

class ScreeningCoordinator: PagedSectionCoordinator {
    
    public unowned var navigationController: UINavigationController
    
    var pages: [InfoPage] { self.sectionData.pages }
    
    private let sectionData: ScreeningSection
    private let completionCallback: NavigationControllerCallback
    
    init(withSectionData sectionData: ScreeningSection,
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
        let viewController = BooleanQuestionsViewController(withQuestions: self.sectionData.questions, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func showSuccess() {
        let infoPageData = InfoPageData(page: self.sectionData.successPage,
                                        addAbortOnboardingButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .center)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func showFailure() {
        let infoPageData = InfoPageData(page: self.sectionData.failurePage,
                                        addAbortOnboardingButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .center)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func popBackToQuestions() {
        guard let questionsViewController = self.navigationController.viewControllers.reversed()
            .first(where: {$0 is BooleanQuestionsViewController }) else {
                assertionFailure("Missing view controller in navigation stack")
            return
        }
        self.navigationController.popToViewController(questionsViewController, animated: true)
    }
}

extension ScreeningCoordinator: InfoPageCoordinator {
    func onInfoPageConfirm(pageData: InfoPageData) {
        switch pageData.page.id {
        case self.sectionData.successPage.id:
            self.completionCallback(self.navigationController)
        case self.sectionData.failurePage.id:
            self.popBackToQuestions()
        default:
            if false == self.handleShowNextPage(forCurrentPage: pageData.page, isOnboarding: true) {
                self.showQuestions()
            }
        }
    }
}

extension ScreeningCoordinator: BooleanQuestionsCoordinator {
    func onBooleanQuestionsSuccess() {
        self.showSuccess()
    }
    
    func onBooleanQuestionsFailure() {
        self.showFailure()
    }
}
