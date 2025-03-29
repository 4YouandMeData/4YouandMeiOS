//
//  OnboardingQuestionsCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 27/03/25.
//

import Foundation
import RxSwift

class OnboardingQuestionsCoordinator {
   
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = true
    
    public unowned var navigationController: UINavigationController
    
    private let sectionData: OnboardingQuestionsSection
    private let completionCallback: NavigationControllerCallback
    private let analytics: AnalyticsService
    private let navigator: AppNavigator
    private let repository: Repository
    
    private let disposeBag = DisposeBag()
    
    var currentPage: Page?
    var currentQuestion: ProfilingQuestion?
    var result: ProfilingResult?
    
    init(withSectionData sectionData: OnboardingQuestionsSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        self.analytics = Services.shared.analytics
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
    }
    
    // MARK: - Private Methods
    
    private func submitUserData() {
        guard let questionId = self.result?.profilingQuestion.id,
              let answer = getOption(result: self.result),
              let answerId = Int(answer.id) else {
                assertionFailure("Missing user data")
                return
        }
        
        self.repository.submitProfilingOption(questionId: questionId,
                                              optionId: answerId)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.showSuccess()
            }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self.navigationController)
            }).disposed(by: self.disposeBag)
    }
    
    private func showSuccess() {
        if let successPage = self.sectionData.successPage {
            self.showResultPage(successPage)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
    
    private func showFailure() {
        guard let failurePage = sectionData.failurePage else {
            self.navigator.abortOnboarding()
            return
        }
        let infoPageData = InfoPageData(page: failurePage,
                                        addAbortOnboardingButton: false,
                                        addCloseButton: false,
                                        allowBackwardNavigation: true,
                                        bodyTextAlignment: .center,
                                        bottomViewStyle: .vertical(backButton: false),
                                        customImageHeight: nil,
                                        defaultButtonFirstLabel: nil,
                                        defaultButtonSecondLabel: nil)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func showQuestion(_ question: ProfilingQuestion) {
        self.currentPage = nil
        self.currentQuestion = question
        let viewController = ProfilingQuestionViewController(withPageData: question, coordinator: self)
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
}

extension OnboardingQuestionsCoordinator: PagedSectionCoordinator {
    
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
        if self.sectionData.failurePage?.id == page.id {
            self.navigator.abortOnboarding()
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

extension OnboardingQuestionsCoordinator: ProfilingQuestionViewCoordinator {
    
    private func showNextOnboardingQuestion(questionId: String) {
        guard let questionIndex = self.sectionData.questions.firstIndex(where: { $0.id == questionId }) else {
            assertionFailure("Missing question in question array")
            return
        }
        
        let nextQuestionIndex = questionIndex + 1
        if nextQuestionIndex == self.sectionData.validQuestions.count {
            self.submitUserData()
        } else {
            let nextQuestion = self.sectionData.validQuestions[nextQuestionIndex]
            self.showQuestion(nextQuestion)
        }
    }
    
    func onQuestionAnsweredSuccess(result: ProfilingResult) {
        // Target logic
        self.result = result
        let matchingTarget = getOption(result: result)
        if let matchingTarget = matchingTarget {
            switch matchingTarget.navigation {
            case .success:
                self.submitUserData()
            case .failure:
                self.showFailure()
            case .next:
                self.showNextOnboardingQuestion(questionId: result.profilingQuestion.id)
            }
        }
    }
    
    func getOption(result: ProfilingResult?) -> ProfilingOption? {
        return result?.profilingQuestion.profilingOptions?.first(where: {
            guard let answer = result?.answer as? ProfilingPickResponse else { return false }
            return $0.id == answer.answerId
        })
    }
}
