//
//  SurveyGroupSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 25/09/2020.
//

import Foundation
import RxSwift

class SurveyGroupSectionCoordinator: ActivitySectionCoordinator {
    
    public weak var navigationController: UINavigationController?
    
    // MARK: - ActivitySectionCoordinator
    var activityPresenter: UIViewController? { return self.navigationController }
    let taskIdentifier: String
    let completionCallback: NotificationCallback
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
    private let sectionData: SurveyGroup
    
    private var answersForSurveys: [SurveyTask: [SurveyResult]] = [:]
    
    init(withTaskIdentifier taskIdentifier: String,
         sectionData: SurveyGroup,
         navigationController: UINavigationController?,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = taskIdentifier
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
    }
    
    // MARK: - ActivitySectionCoordinator
    
    public func getStartingPage() -> UIViewController? {
        guard let firstSurvey = self.sectionData.validSurveys.first else {
            assertionFailure("Missing survey for current survey group")
            return nil
        }
        if let navigationController = self.navigationController {
            return self.getSurveyViewController(forSurvey: firstSurvey,
                                                navigationController: navigationController,
                                                isFirstStartingPage: true)
        } else {
            let navigationController = UINavigationController()
            self.navigationController = navigationController
            let startingPage = self.getSurveyViewController(forSurvey: firstSurvey,
                                                            navigationController: navigationController,
                                                            isFirstStartingPage: true)
            navigationController.pushViewController(startingPage, animated: false)
            return navigationController
        }
    }
    
    // MARK: - Private Methods
    
    private func getSurveyViewController(forSurvey survey: SurveyTask,
                                         navigationController: UINavigationController,
                                         isFirstStartingPage: Bool) -> UIViewController {
        let coordinator = SurveySectionCoordinator(withSectionData: survey,
                                                   navigationController: navigationController,
                                                   completionCallback: { [weak self] (_, survey, answers) in
                                                    guard let self = self else { return }
                                                    self.onSurveyCompleted(survey, answers: answers)
                                                   },
                                                   delayCallback: { [weak self] in
                                                    guard let self = self else { return }
                                                    self.delayActivity()
                                                   })
        return coordinator.getStartingPage(isFirstStartingPage: isFirstStartingPage)
    }
    
    private func showSurvey(_ survey: SurveyTask) {
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing expected navigation controller")
            return
        }
        let surveyStartingViewController = self.getSurveyViewController(forSurvey: survey,
                                                                        navigationController: navigationController,
                                                                        isFirstStartingPage: false)
        navigationController.pushViewController(surveyStartingViewController, animated: true)
    }
    
    private func onSurveyCompleted(_ survey: SurveyTask, answers: [SurveyResult]) {
        self.answersForSurveys[survey] = answers
        self.showNextSurvey(forCurrentSurvey: survey)
    }
    
    private func showNextSurvey(forCurrentSurvey currentSurvey: SurveyTask) {
        guard let currentSurveyIndex = self.sectionData.validSurveys.firstIndex(of: currentSurvey) else {
            assertionFailure("Missing survey in survey array")
            self.cancelSurveyGroup()
            return
        }
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing expected navigation controller")
            return
        }
        
        let nextCurrentSurveyIndex = currentSurveyIndex + 1
        if nextCurrentSurveyIndex == self.sectionData.validSurveys.count {
            var aggregatedAnswers: [SurveyResult] = []
            self.answersForSurveys.forEach { answersForSurvey in
                aggregatedAnswers.append(contentsOf: answersForSurvey.value)
            }
            self.repository.sendSurveyTaskResult(surveyTaskId: self.taskIdentifier, results: aggregatedAnswers)
                .subscribe( onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.completionCallback()
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.navigator.handleError(error: error, presenter: navigationController)
                }).disposed(by: self.disposeBag)
        } else {
            let nextSurvey = self.sectionData.validSurveys[nextCurrentSurveyIndex]
            self.showSurvey(nextSurvey)
        }
    }
    
    private func cancelSurveyGroup() {
        print("Survey group cancelled")
        self.completionCallback()
    }
}
