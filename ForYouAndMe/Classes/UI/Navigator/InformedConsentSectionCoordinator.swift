//
//  InformedConsentSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/06/2020.
//

import Foundation

class InformedConsentSectionCoordinator {
    
    public unowned var navigationController: UINavigationController
    
    private let sectionData: InformedConsentSection
    private let completionCallback: NavigationControllerCallback
    
    var answers: [Question: PossibleAnswer] = [:]
    
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
    
    private func showQuestion(_ question: Question) {
        let viewController = QuestionViewController(withQuestion: question, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func validateAnswers() -> Bool {
        // TODO: Implement correct answers validation
        
        // Current hardcoded logic: success if all answers - max 1 answer are correct
        let minimumCorrectAnswerCount = self.answers.count - 1
        var currentCorrectAnswerCount = 0
        self.answers.values.forEach { currentCorrectAnswerCount += $0.correct ? 1 : 0 }
        return currentCorrectAnswerCount >= minimumCorrectAnswerCount
    }
}

extension InformedConsentSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [InfoPage] { self.sectionData.pages }
    
    func performCustomPrimaryButtonNavigation(page: InfoPage) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController)
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: InfoPage) {
        if let firstQuestion = self.sectionData.questions.first {
            self.showQuestion(firstQuestion)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension InformedConsentSectionCoordinator: QuestionViewCoordinator {
    func onQuestionAnsweredSuccess(possibleAnswer: PossibleAnswer, forQuestion question: Question) {
        self.answers[question] = possibleAnswer
        
        guard let questionIndex = self.sectionData.questions.firstIndex(of: question) else {
            assertionFailure("Missing question in question array")
            return
        }
        
        let nextQuestionIndex = questionIndex + 1
        if nextQuestionIndex == self.sectionData.questions.count {
            assert(self.answers.count == self.sectionData.questions.count, "Mismatch answers count and questions count")
            if self.validateAnswers() {
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

extension Question: Hashable, Equatable {
    static func == (lhs: Question, rhs: Question) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
