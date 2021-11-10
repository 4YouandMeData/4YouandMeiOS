//
//  ScreeningSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

class ScreeningSectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = true
    
    public unowned var navigationController: UINavigationController
    
    private let sectionData: ScreeningSection
    private let completionCallback: NavigationControllerCallback
    private let analyticsService: AnalyticsService
    
    init(withSectionData sectionData: ScreeningSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        self.analyticsService = Services.shared.analytics
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        let infoPageData = InfoPageData.createWelcomePageData(withPage: self.sectionData.welcomePage)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }
    
    // MARK: - Private Methods
    
    private func showQuestions() {
        let viewController = BooleanQuestionsViewController(withQuestions: self.sectionData.questions, coordinator: self)
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func showSuccess() {
        if let successPage = self.sectionData.successPage {
            self.showResultPage(successPage)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
    
    private func showFailure() {
        self.showResultPage(self.sectionData.failurePage)
    }
    
    private func popBackToQuestions() {
        self.navigationController.popToExpectedViewController(ofClass: BooleanQuestionsViewController.self, animated: true)
    }
}

extension ScreeningSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController)
            return true
        } else if self.sectionData.failurePage.id == page.id {
            self.popBackToQuestions()
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        if self.sectionData.questions.count > 0 {
            self.showQuestions()
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension ScreeningSectionCoordinator: BooleanQuestionsCoordinator {
    func onBooleanQuestionsSubmit(answers: [Answer]) {
        self.analyticsService.track(event: .screeningQuizCompleted(answers: answers))
        if answers.validate(withMinimumCorrectAnswers: self.sectionData.minimumCorrectAnswers) {
            self.showSuccess()
        } else {
            self.showFailure()
        }
    }
}
