//
//  InformedConsentSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/06/2020.
//

import Foundation

class InformedConsentSectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = true
    
    public unowned var navigationController: UINavigationController
    
    private let sectionData: InformedConsentSection
    private let completionCallback: NavigationControllerCallback
    private let analytics: AnalyticsService
    
    var currentPage: Page?
    var currentQuestion: Question?
    var answers: [Answer] = []
    
    init(withSectionData sectionData: InformedConsentSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        self.analytics = Services.shared.analytics
    }
    
    // MARK: - Private Methods
    
    private func showSuccess() {
        if let successPage = self.sectionData.successPage {
            self.showResultPage(successPage)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
    
    private func showFailure() {
        let infoPageData = InfoPageData(page: self.sectionData.failurePage,
                                        addAbortOnboardingButton: false,
                                        addCloseButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .center,
                                        bottomViewStyle: .vertical(backButton: true),
                                        customImageHeight: nil,
                                        defaultButtonFirstLabel: nil,
                                        defaultButtonSecondLabel: nil)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func showQuestion(_ question: Question) {
        self.currentPage = nil
        self.currentQuestion = question
        let viewController = QuestionViewController(withQuestion: question, coordinator: self)
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
}

extension InformedConsentSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func getStartingPage() -> UIViewController {
        let infoPageData = InfoPageData.createWelcomePageData(withPage: self.sectionData.welcomePage)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        self.currentPage = page
        self.currentQuestion = nil
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController)
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        self.currentPage = page
        self.currentQuestion = nil
        if let firstQuestion = self.sectionData.questions.first {
            self.showQuestion(firstQuestion)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension InformedConsentSectionCoordinator: QuestionViewCoordinator {
    func onQuestionAnsweredSuccess(answer: Answer) {
        if let answerIndex = self.answers.firstIndex(where: { $0.question == answer.question }) {
            self.answers[answerIndex] = answer
        } else {
            self.answers.append(answer)
        }
        
        guard let questionIndex = self.sectionData.questions.firstIndex(of: answer.question) else {
            assertionFailure("Missing question in question array")
            return
        }
        
        let nextQuestionIndex = questionIndex + 1
        if nextQuestionIndex == self.sectionData.questions.count {
            assert(self.answers.count == self.sectionData.questions.count, "Mismatch answers count and questions count")
            self.analytics.track(event: .informedConsentQuizCompleted(answers: self.answers))
            if self.answers.validate(withMinimumCorrectAnswers: self.sectionData.minimumCorrectAnswers) {
                self.showSuccess()
            } else {
                self.showFailure()
            }
        } else {
            let nextQuestion = self.sectionData.questions[nextQuestionIndex]
            self.showQuestion(nextQuestion)
        }
    }
}
