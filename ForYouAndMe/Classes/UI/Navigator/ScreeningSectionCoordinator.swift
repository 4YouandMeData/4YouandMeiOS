//
//  ScreeningSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

class ScreeningSectionCoordinator {
    
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
        let infoPageData = InfoPageData.createWelcomePageData(withinfoPage: self.sectionData.welcomePage)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }
    
    // MARK: - Private Methods
    
    private func showQuestions() {
        let viewController = BooleanQuestionsViewController(withQuestions: self.sectionData.questions, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
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
        let infoPageData = InfoPageData.createResultPageData(withinfoPage: failurePage)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func popBackToQuestions() {
        self.navigationController.popToExpectedViewController(ofClass: BooleanQuestionsViewController.self, animated: true)
    }
}

extension ScreeningSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [InfoPage] { self.sectionData.pages }
    
    func performCustomPrimaryButtonNavigation(page: InfoPage) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController)
            return true
        } else if self.sectionData.failurePage?.id == page.id {
            self.popBackToQuestions()
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: InfoPage) {
        if self.sectionData.questions.count > 0 {
            self.showQuestions()
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension ScreeningSectionCoordinator: BooleanQuestionsCoordinator {
    func onBooleanQuestionsSuccess() {
        self.showSuccess()
    }
    
    func onBooleanQuestionsFailure() {
        self.showFailure()
    }
}
