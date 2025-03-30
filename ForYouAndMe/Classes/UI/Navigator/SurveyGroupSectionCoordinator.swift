//
//  SurveyGroupSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 25/09/2020.
//

import Foundation
import RxSwift

class SurveyGroupSectionCoordinator: PagedActivitySectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
        
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = false
    
    // MARK: - ActivitySectionCoordinator
    let taskIdentifier: String
    let completionCallback: NotificationCallback
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
    // MARK: - PagedActivitySectionCoordinator
    weak var activitySectionViewController: ActivitySectionViewController?
    let pagedSectionData: PagedSectionData
    var currentlyRescheduledTimes: Int
    var maxRescheduleTimes: Int
//    private var progressView: UIProgressView?
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
    
    deinit {
        print("SurveyGroupSectionCoordinator - deinit")
    }
    
    // MARK: - Private Methods
    
//    private func setupProgressViewIfNeeded() {
//        guard self.progressView == nil else {
//            return
//        }
//            
//        let navigationBar = navigationController.navigationBar
//
//        let progressView = UIProgressView(frame: .zero)
//        progressView.translatesAutoresizingMaskIntoConstraints = false
//        progressView.progress = 0.0
//        progressView.trackTintColor = ColorPalette.color(withType: .fourthText).applyAlpha(0.3)
//        progressView.progressTintColor = ColorPalette.color(withType: .primary)
//        navigationBar.addSubview(progressView)
//        
//        progressView.autoPinEdge(.leading, to: .leading, of: navigationBar, withOffset: Constants.Style.DefaultHorizontalMargins)
//        progressView.autoPinEdge(.trailing, to: .trailing, of: navigationBar, withOffset: -Constants.Style.DefaultHorizontalMargins)
//        progressView.autoPinEdge(.top, to: .bottom, of: navigationBar, withOffset: 2)
//        
//        self.progressView = progressView
//    }
    
//    private func updateGlobalProgress(currentSurveyIndex: Int) {
//        
//        guard let progressView = self.progressView else { return }
//        
//        let totalQuestionsCount = self.sectionData.allValidQuestions.count
//        
//        guard totalQuestionsCount > 0 else {
//            progressView.setProgress(0.0, animated: false)
//            return
//        }
//        
//        let fraction = Float(currentSurveyIndex) / Float(totalQuestionsCount)
//        progressView.setProgress(fraction, animated: true)
//    }
    
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
        
        guard let currentSurveyIndex = self.sectionData.validSurveys.firstIndex(of: survey) else {
            assertionFailure("Survey not founds in validSurveys")
            // Fallback
            return UIViewController()
        }
        
        let previousSurveys = self.sectionData.validSurveys.prefix(upTo: currentSurveyIndex)
        let pastQuestions = previousSurveys.flatMap { $0.validQuestions }.count
        let totalQuestionsCount = self.sectionData.allValidQuestions.count
        
//        self.setupProgressViewIfNeeded()
            
//        let progressFraction = Float(pastQuestions) / Float(totalQuestionsCount)
//        self.progressView?.setProgress(progressFraction, animated: true)

        let coordinator = SurveySectionCoordinator(withSectionData: survey,
                                                   navigationController: navigationController,
                                                   questionsSoFar: pastQuestions,
                                                   totalQuestions: totalQuestionsCount,
                                                   completionCallback: { [weak self] (_, survey, answers, target) in
            guard let self = self else { return }
            self.onSurveyCompleted(survey, answers: answers, target: target)
        })
        
//        coordinator.onQuestionAnswered = { [weak self] index in
//            guard let self = self else { return }
//            self.updateGlobalProgress(currentSurveyIndex: currentSurveyIndex + index)
//        }
        return coordinator.getStartingPage()
    }
    
    private func showSurvey(_ survey: SurveyTask) {
        let surveyStartingViewController = self.getSurveyViewController(forSurvey: survey,
                                                                        navigationController: self.navigationController,
                                                                        isFirstStartingPage: false)
        self.navigationController.pushViewController(surveyStartingViewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func onSurveyCompleted(_ survey: SurveyTask, answers: [SurveyResult], target: SurveyTarget? = nil) {
        self.answersForSurveys[survey] = answers
        self.showNextSurvey(forCurrentSurvey: survey, target: target)
    }
    
    private func showNextSurvey(forCurrentSurvey currentSurvey: SurveyTask, target: SurveyTarget? = nil) {
        guard let currentSurveyIndex = self.sectionData.validSurveys.firstIndex(of: currentSurvey) else {
            assertionFailure("Missing survey in survey array")
            self.cancelSurveyGroup()
            return
        }
        
        let nextCurrentSurveyIndex: Int
            
        if let blockId = target?.blockId,
           !blockId.isEmpty {
            if let index = self.sectionData.validSurveys.firstIndex(where: { $0.id == blockId }) {
                nextCurrentSurveyIndex = index
            } else {
                nextCurrentSurveyIndex = currentSurveyIndex + 1
            }
        } else {
            nextCurrentSurveyIndex = currentSurveyIndex + 1
        }
        if nextCurrentSurveyIndex == self.sectionData.validSurveys.count {
            var aggregatedAnswers: [SurveyResult] = []
            self.answersForSurveys.forEach { answersForSurvey in
                aggregatedAnswers.append(contentsOf: answersForSurvey.value)
            }
            self.repository.sendSurveyTaskResult(surveyTaskId: self.taskIdentifier, results: aggregatedAnswers)
                .addProgress()
                .subscribe( onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.showSuccessPage()
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
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
