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
    private let delayCallback: NotificationCallback
    
    private var results: [SurveyResult] = []
    
    init(withSectionData sectionData: SurveyTask,
         navigationController: UINavigationController,
         completionCallback: @escaping SurveySectionCallback,
         delayCallback: @escaping NotificationCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        self.delayCallback = delayCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage(isFirstStartingPage: Bool) -> UIViewController {
        
        let infoPageData = InfoPageData(page: self.sectionData.welcomePage,
                                addAbortOnboardingButton: false,
                                addCloseButton: isFirstStartingPage,
                                allowBackwardNavigation: false,
                                bodyTextAlignment: .left,
                                bottomViewStyle: isFirstStartingPage ? .horizontal : .singleButton,
                                customImageHeight: nil)
        
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
            self.completionCallback(self.navigationController, self.sectionData, self.results)
        }
    }
    
    private func showQuestion(_ question: SurveyQuestion) {
        guard let questionIndex = self.sectionData.questions.firstIndex(where: { $0.id == question.id }) else {
            assertionFailure("Missing question in question array")
            return
        }
        let pageData = SurveyQuestionPageData(question: question,
                                              questionNumber: questionIndex + 1,
                                              totalQuestions: self.sectionData.questions.count)
        let viewController = SurveyQuestionViewController(withPageData: pageData, coordinator: self)
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
            self.completionCallback(self.navigationController, self.sectionData, self.results)
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        self.showQuestions()
    }
    
    func onUnhandledSecondaryButtonNavigation(page: Page) {
        self.delayCallback()
    }
}

extension SurveySectionCoordinator: SurveyQuestionViewCoordinator {
    func onSurveyQuestionAnsweredSuccess(result: SurveyResult) {
        
        guard result.isValid else {
            assertionFailure("Result validation failed")
            self.showNextSurveyQuestion(questionId: result.question.id)
            return
        }
        
        if let resultIndex = self.results.firstIndex(where: { $0.question == result.question }) {
            self.results[resultIndex] = result
        } else {
            self.results.append(result)
        }
        
        // Skip logic
        var matchingTarget: SurveyTarget?
        switch result.question.questionType {
        case .numerical:
            var numericValue = result.numericValue
            if let minimum = result.question.minimum, (result.answer as? String) == Constants.Survey.NumericTypeMinValue {
                numericValue = minimum - 1
            }
            if let maximum = result.question.maximum, (result.answer as? String) == Constants.Survey.NumericTypeMaxValue {
                numericValue = maximum + 1
            }
            if let numericValue = numericValue {
                matchingTarget = result.question.targets?.getTargetMatchingCriteria(forNumber: numericValue)
            }
        case .pickOne:
            if let optionsIdentifiers = result.optionsIdentifiers {
                matchingTarget = result.question.options?
                    .first(where: { optionsIdentifiers.contains($0.id) && $0.targets?.first != nil })?.targets?.first
            }
        case .pickMany:
            if let optionsIdentifiers = result.optionsIdentifiers {
                matchingTarget = result.question.options?
                    .first(where: { optionsIdentifiers.contains($0.id) && $0.targets?.first != nil })?.targets?.first
            }
        case .textInput:
            break
        case .dateInput:
            break
        case .scale:
            if let numericValue = result.numericValue {
                matchingTarget = result.question.targets?.getTargetMatchingCriteria(forNumber: numericValue)
            }
        case .range:
            if let numericValue = result.numericValue {
                matchingTarget = result.question.targets?.getTargetMatchingCriteria(forNumber: numericValue)
            }
        }
        
        if let matchingTarget = matchingTarget {
            if matchingTarget.questionId == Constants.Survey.TargetQuit {
                self.showSuccess()
            } else {
                guard let question = self.sectionData.questions.first(where: { $0.id == matchingTarget.questionId }) else {
                    assertionFailure("Missing question in question array")
                    self.showNextSurveyQuestion(questionId: result.question.id)
                    return
                }
                self.showQuestion(question)
            }
        } else {
            self.showNextSurveyQuestion(questionId: result.question.id)
        }
    }
    
    func onSurveyQuestionSkipped(questionId: String) {
        self.showNextSurveyQuestion(questionId: questionId)
    }
}

extension SurveyResult {
    var isValid: Bool {
        switch self.question.questionType {
        case .numerical:
            guard let stringValue = self.answer as? String else { return false }
            if stringValue == Constants.Survey.NumericTypeMinValue {
                return true
            } else if stringValue == Constants.Survey.NumericTypeMaxValue {
                return true
            } else if let intValue = Int(stringValue) {
                if let minimum = self.question.minimum, intValue < minimum {
                    return false
                }
                if let maximum = self.question.maximum, intValue > maximum {
                    return false
                }
                return true
            }
            return false
        case .pickOne:
            guard let options = self.question.options else { return false }
            guard let optionIdentifier = self.answer as? String else { return false }
            return options.contains(where: { $0.id == optionIdentifier })
        case .pickMany:
            guard let options = self.question.options else { return false }
            guard let optionIdentifiers = self.answer as? [String] else { return false }
            return optionIdentifiers.allSatisfy(options.map { $0.id }.contains)
        case .textInput:
            guard let text = self.answer as? String else { return false }
            if let maxCharacters = self.question.maxCharacters, text.count > maxCharacters { return false }
            return !text.isEmpty
        case .dateInput:
            guard let dateStr = self.answer as? String else { return false }
            guard let date = DateStrategy.dateFormatter.date(from: dateStr) else { return false }
            if let minimumDate = self.question.minimumDate, date < minimumDate { return false }
            if let maximumDate = self.question.maximumDate, date > maximumDate { return false }
            return true
        case .scale:
            guard let value = self.answer as? Int else { return false }
            if let minimum = self.question.minimum, value < minimum { return false }
            if let maximum = self.question.maximum, value > maximum { return false }
            if let interval = self.question.interval, value % interval != 0 { return false }
            return true
        case .range:
            guard let value = self.answer as? Int else { return false }
            if let minimum = self.question.minimum, value < minimum { return false }
            if let maximum = self.question.maximum, value > maximum { return false }
            return true
        }
    }
    
    var numericValue: Int? {
        switch self.question.questionType {
        case .numerical:
            guard let stringValue = self.answer as? String else { return nil }
            return Int(stringValue)
        case .pickOne: return nil
        case .pickMany: return nil
        case .textInput: return nil
        case .dateInput: return nil
        case .scale: return self.answer as? Int
        case .range: return self.answer as? Int
        }
    }
    
    var optionsIdentifiers: [String]? {
        switch self.question.questionType {
        case .numerical: return nil
        case .pickOne:
            guard let optionIdentifier = self.answer as? String else { return nil }
            return [optionIdentifier]
        case .pickMany: return self.answer as? [String]
        case .textInput: return nil
        case .dateInput: return nil
        case .scale: return nil
        case .range: return nil
        }
    }
}

extension Array where Element == SurveyTarget {
    func getTargetMatchingCriteria(forNumber number: Int) -> SurveyTarget? {
        self.first { target in
            guard let criteria = target.criteria else {
                assertionFailure("Missing expected criteria")
                return true
            }
            switch criteria {
            case .range:
                if let minimum = target.minimum, number < minimum { return false }
                if let maximum = target.maximum, number > maximum { return false }
                return true
            }
        }
    }
}
