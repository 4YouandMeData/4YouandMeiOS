//
//  SurveyGroupSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 25/09/2020.
//

import Foundation
import RxSwift

class SurveyGroupSectionCoordinator: PagedActivitySectionCoordinator {
    
    // MARK: - ActivitySectionCoordinator
    var activityPresenter: UIViewController? { return self.navigationController }
    let taskIdentifier: String
    let completionCallback: NotificationCallback
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
    // MARK: - PagedActivitySectionCoordinator
    weak var internalNavigationController: UINavigationController?
    let pagedSectionData: PagedSectionData
    var currentlyRescheduledTimes: Int
    var maxRescheduleTimes: Int
    var coreViewController: UIViewController? { self.getFirstSurveyViewController() }
    
    private let sectionData: SurveyGroup
    
    private var answersForSurveys: [SurveyTask: [SurveyResult]] = [:]
    
    init(withTask task: Feed,
         sectionData: SurveyGroup,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = task.id
        self.sectionData = sectionData
        self.currentlyRescheduledTimes = task.rescheduledTimes ?? 0
        self.maxRescheduleTimes = sectionData.rescheduleTimes ?? 0
        self.pagedSectionData = sectionData.pagedSectionData
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
    }
    
    // MARK: - Private Methods
    
    private func getFirstSurveyViewController() -> UIViewController? {
        guard let firstSurvey = self.sectionData.validSurveys.first else {
            assertionFailure("Missing survey for current survey group")
            return nil
        }
        return self.getSurveyViewController(forSurvey: firstSurvey,
                                            navigationController: self.navigationController,
                                            isFirstStartingPage: true)
    }
    
    private func getSurveyViewController(forSurvey survey: SurveyTask,
                                         navigationController: UINavigationController,
                                         isFirstStartingPage: Bool) -> UIViewController {
        let coordinator = SurveySectionCoordinator(withSectionData: survey,
                                                   navigationController: navigationController,
                                                   completionCallback: { [weak self] (_, survey, answers) in
                                                    guard let self = self else { return }
                                                    self.onSurveyCompleted(survey, answers: answers)
                                                   })
        return coordinator.getStartingPage()
    }
    
    private func showSurvey(_ survey: SurveyTask) {
        let surveyStartingViewController = self.getSurveyViewController(forSurvey: survey,
                                                                        navigationController: self.navigationController,
                                                                        isFirstStartingPage: false)
        self.navigationController.pushViewController(surveyStartingViewController, animated: true)
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
                    self.showSuccessPage()
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.navigator.handleError(error: error, presenter: self.navigationController)
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
