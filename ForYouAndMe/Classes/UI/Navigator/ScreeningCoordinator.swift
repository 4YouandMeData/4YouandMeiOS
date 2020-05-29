//
//  ScreeningCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

class ScreeningCoordinator {
    
    public unowned var navigationController: UINavigationController
    
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
                                        confirmButtonText: nil,
                                        usePageNavigation: false)
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
                                        confirmButtonText: nil,
                                        usePageNavigation: false)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func showFailure() {
        let infoPageData = InfoPageData(page: self.sectionData.failurePage,
                                        addAbortOnboardingButton: false,
                                        confirmButtonText: StringsProvider.string(forKey: .screeningFailureRetryButton),
                                        usePageNavigation: false)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func popBackToQuestions() {
        guard let questionsViewController = self.navigationController.viewControllers
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
        case self.sectionData.welcomePage.id:
            self.showQuestions()
        case self.sectionData.successPage.id:
            self.completionCallback(self.navigationController)
        case self.sectionData.failurePage.id:
            self.popBackToQuestions()
        default:
            assertionFailure("Unexptected page")
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
