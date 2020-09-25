//
//  SurveySectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation

class SurveySectionCoordinator {
    
    typealias SurveySectionCallback = (UINavigationController, SurveyTask, [SurveyResult]) -> Void
    
    public unowned var navigationController: UINavigationController
    
    private let sectionData: SurveyTask
    private let completionCallback: SurveySectionCallback
    
    private var answers: [SurveyResult] = []
    
    init(withSectionData sectionData: SurveyTask,
         navigationController: UINavigationController,
         completionCallback: @escaping SurveySectionCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage(showCloseButton: Bool) -> UIViewController {
        let infoPageData = InfoPageData.createWelcomePageData(withPage: self.sectionData.welcomePage, showCloseButton: showCloseButton)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }
    
    // MARK: - Private Methods
    
    private func showQuestions() {
        if let question = self.sectionData.questions.first {
            self.showQuestion(question)
        } else {
            assertionFailure("Missing questions for current survey")
            self.showSuccess()
        }
    }
    
    private func showSuccess() {
        if let successPage = self.sectionData.successPage {
            let infoPageData = InfoPageData.createResultPageData(withPage: successPage)
            let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
            self.navigationController.pushViewController(viewController, animated: true)
        } else {
            self.completionCallback(self.navigationController, self.sectionData, self.answers)
        }
    }
    
    private func showQuestion(_ question: SurveyQuestion) {
        let viewController = SurveyQuestionViewController(withQuestion: question, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func showNextSurveyQuestion(questionId: String) {
        guard let questionIndex = self.sectionData.questions.firstIndex(where: { $0.id == questionId }) else {
            assertionFailure("Missing question in question array")
            return
        }
        
        let nextQuestionIndex = questionIndex + 1
        if nextQuestionIndex == self.sectionData.questions.count {
            self.showSuccess()
        } else {
            let nextQuestion = self.sectionData.questions[nextQuestionIndex]
            self.showQuestion(nextQuestion)
        }
    }
}

extension SurveySectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController, self.sectionData, self.answers)
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        self.showQuestions()
    }
}

extension SurveySectionCoordinator: SurveyQuestionViewCoordinator {
    func onSurveyQuestionAnsweredSuccess(answer: SurveyResult) {
        
        // TODO: Apply skip logic
        
        if let answerIndex = self.answers.firstIndex(where: { $0.questionId == answer.questionId }) {
            self.answers[answerIndex] = answer
        } else {
            self.answers.append(answer)
        }
        
        self.showNextSurveyQuestion(questionId: answer.questionId)
    }
    
    func onSurveyQuestionSkipped(questionId: String) {
        self.showNextSurveyQuestion(questionId: questionId)
    }
}
