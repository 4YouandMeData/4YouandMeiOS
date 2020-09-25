//
//  SurveyGroupSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 25/09/2020.
//

import Foundation
import RxSwift

class SurveyGroupSectionCoordinator: ActivitySectionCoordinator {
    
    private static let sendResultAtTheEnd: Bool = true
    
    public weak var navigationController: UINavigationController?
    
    private let sectionData: SurveyGroup
    private let completionCallback: NotificationCallback
    
    private let navigator: AppNavigator
    private let repository: Repository
    
    private let disposeBag = DisposeBag()
    
    private var answersForSurveys: [SurveyTask: [SurveyResult]] = [:]
    
    init(withSectionData sectionData: SurveyGroup,
         navigationController: UINavigationController?,
         completionCallback: @escaping NotificationCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
    }
    
    // MARK: - ActivitySectionCoordinator
    
    public func getStartingPage() -> UIViewController? {
        guard let firstSurvey = self.sectionData.surveys.first else {
            assertionFailure("Missing survey for current survey group")
            return nil
        }
        if let navigationController = self.navigationController {
            return self.getSurveyViewController(forSurvey: firstSurvey,
                                                navigationController: navigationController,
                                                showCloseButton: true)
        } else {
            let navigationController = UINavigationController()
            self.navigationController = navigationController
            let startingPage = self.getSurveyViewController(forSurvey: firstSurvey,
                                                            navigationController: navigationController,
                                                            showCloseButton: true)
            navigationController.pushViewController(startingPage, animated: false)
            return navigationController
        }
    }
    
    // MARK: - Private Methods
    
    private func getSurveyViewController(forSurvey survey: SurveyTask,
                                         navigationController: UINavigationController,
                                         showCloseButton: Bool) -> UIViewController {
        let coordinator = SurveySectionCoordinator(withSectionData: survey,
                                                   navigationController: navigationController,
                                                   completionCallback: { [weak self] (_, survey, answers) in
                                                    guard let self = self else { return }
                                                    self.onSurveyCompleted(survey, answers: answers)
                                                   })
        return coordinator.getStartingPage(showCloseButton: showCloseButton)
    }
    
    private func showSurvey(_ survey: SurveyTask) {
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing expected navigation controller")
            return
        }
        let surveyStartingViewController = self.getSurveyViewController(forSurvey: survey,
                                                                                navigationController: navigationController,
                                                                                showCloseButton: false)
        navigationController.pushViewController(surveyStartingViewController, animated: true)
    }
    
    private func onSurveyCompleted(_ survey: SurveyTask, answers: [SurveyResult]) {
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing expected navigation controller")
            return
        }
        if Self.sendResultAtTheEnd {
            self.answersForSurveys[survey] = answers
            self.showNextSurvey(forCurrentSurvey: survey)
        } else {
            self.navigator.pushProgressHUD()
            self.repository.sendSurveyTaskResult(surveyTaskId: survey.id, results: answers)
                .subscribe( onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.showNextSurvey(forCurrentSurvey: survey)
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.navigator.handleError(error: error, presenter: navigationController)
                }).disposed(by: self.disposeBag)
        }
    }
    
    private func showNextSurvey(forCurrentSurvey currentSurvey: SurveyTask) {
        guard let currentSurveyIndex = self.sectionData.surveys.firstIndex(of: currentSurvey) else {
            assertionFailure("Missing survey in survey array")
            self.cancelSurveyGroup()
            return
        }
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing expected navigation controller")
            return
        }
        
        let nextCurrentSurveyIndex = currentSurveyIndex + 1
        if nextCurrentSurveyIndex == self.sectionData.surveys.count {
            if Self.sendResultAtTheEnd {
                var resultsSendRequests: [Single<()>] = []
                self.answersForSurveys.forEach { answersForSurvey in
                    let surveyTask = answersForSurvey.key
                    let answers = answersForSurvey.value
                    resultsSendRequests.append(self.repository.sendSurveyTaskResult(surveyTaskId: surveyTask.id, results: answers))
                }
                Single<()>.zip(resultsSendRequests)
                    .subscribe( onSuccess: { [weak self] _ in
                        guard let self = self else { return }
                        self.navigator.popProgressHUD()
                        self.completionCallback()
                    }, onError: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.popProgressHUD()
                        self.navigator.handleError(error: error, presenter: navigationController)
                    }).disposed(by: self.disposeBag)
            } else {
                self.completionCallback()
            }
        } else {
            let nextSurvey = self.sectionData.surveys[nextCurrentSurveyIndex]
            self.showSurvey(nextSurvey)
        }
    }
    
    private func cancelSurveyGroup() {
        print("Survey group cancelled")
        self.completionCallback()
    }
}
