//
//  MenstrualEntryCoordinator.swift
//  ForYouAndMe
//
//  FUAM-2935 — Drives the 5-step menstrual cycle diary wizard.
//  FUAM-3243 — When the menstrual baseline (UserSetting) has never been
//  configured, the wizard is prefixed in-line by the 2 baseline questions
//  ("had a period in the past 3 months?" + "date of last period"), so the
//  user flows straight through into the diary steps instead of the baseline
//  being a separate modal that has to dismiss and re-present the wizard.
//

import UIKit
import RxSwift

final class MenstrualEntryCoordinator: PagedActivitySectionCoordinator {

    // MARK: - Coordinator requirements
    var hidesBottomBarWhenPushed: Bool = false
    var alert: Alert?

    // MARK: - ActivitySectionCoordinator requirements
    let repository: Repository
    let navigator: AppNavigator
    let taskIdentifier: String
    let disposeBag = DisposeBag()
    var activityPresenter: UIViewController? { activitySectionViewController }
    var completionCallback: NotificationCallback

    // MARK: - PagedSectionCoordinator requirements
    var pages: [Page] { pagedSectionData.pages }
    var addAbortOnboardingButton: Bool = false

    var navigationController: UINavigationController {
        guard let nav = activitySectionViewController?.internalNavigationController else {
            fatalError("ActivitySectionViewController not initialized")
        }
        return nav
    }

    // MARK: - PagedActivitySectionCoordinator requirements
    var activitySectionViewController: ActivitySectionViewController?
    let pagedSectionData: PagedSectionData
    let coreViewController: UIViewController? = nil
    var currentlyRescheduledTimes: Int = 0
    let maxRescheduleTimes: Int = 0

    // MARK: - Collected user data
    private let variant: FlowVariant
    /// Feed task id when the wizard is launched from the pinned menstrual
    /// feed alert (FUAM-2932). When set, the coordinator acknowledges the
    /// task via `sendTaskResult` after the diary note is persisted, so the
    /// BE removes the card from the next feed refresh. `nil` for FAB,
    /// settings, and "add another date" entry points where there is no
    /// underlying feed task to close.
    private let feedTaskId: String?
    /// FUAM-3243: when `true` the flow opens with the 2 baseline questions
    /// before the diary steps, and persists the answers via PATCH /v1/user_setting
    /// before continuing.
    private let requiresBaselineOnboarding: Bool
    private var baselineHadPeriod3Mo: MenstrualHadPeriod3Mo?
    private var selectedDate: Date?
    private var flowAmount: MenstrualFlowAmount?
    private var periodRelated: MenstrualPeriodRelated?
    private var periodRelatedExplanation: String?
    private var note: String?

    // MARK: - Initialization
    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         variant: FlowVariant,
         feedTaskId: String? = nil,
         requiresBaselineOnboarding: Bool = false,
         completion: @escaping NotificationCallback) {
        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
        self.variant = variant
        self.feedTaskId = feedTaskId
        self.requiresBaselineOnboarding = requiresBaselineOnboarding
        self.completionCallback = completion

        let sequence: [Page] = [
            .menstrualWhen,
            .menstrualDate,
            .menstrualFlow,
            .menstrualPeriodRelated,
            .menstrualNote
        ]
        self.pagedSectionData = PagedSectionData(
            welcomePage: sequence[0],
            successPage: nil,
            pages: sequence
        )
    }

    // MARK: - Flow start
    func getStartingPage() -> UIViewController {
        // FUAM-3243: open with the baseline question when the user has never
        // configured it; otherwise jump straight into the diary wizard.
        let startingViewController: UIViewController
        if requiresBaselineOnboarding {
            let onboardingVC = MenstrualOnboardingPeriod3MoViewController()
            onboardingVC.delegate = self
            startingViewController = onboardingVC
        } else {
            startingViewController = makeWhenViewController()
        }

        let activityVC = ActivitySectionViewController(coordinator: self,
                                                       startingViewController: startingViewController)
        self.activitySectionViewController = activityVC
        return activityVC
    }

    private func makeWhenViewController() -> MenstrualWhenViewController {
        let whenVC = MenstrualWhenViewController(variant: variant)
        whenVC.delegate = self
        whenVC.alert = self.alert
        return whenVC
    }

    // MARK: - Baseline onboarding → wizard hand-off (FUAM-3243)

    /// Advance straight into the diary wizard and persist the baseline answers
    /// in the background — the screen transition is the feedback, no blocking
    /// HUD. Replacing the stack (vs. pushing) makes the wizard's close button
    /// cancel the whole flow with nothing stale left underneath.
    private func saveBaselineThenStartWizard(lastPeriodDate: Date?) {
        guard let hadPeriod3Mo = self.baselineHadPeriod3Mo else {
            // Defensive: step 1 always sets this before we get here.
            completionCallback()
            return
        }
        self.navigationController.setViewControllers([self.makeWhenViewController()], animated: true)
        self.repository
            .sendMenstrualUserSettings(hadPeriod3Mo: hadPeriod3Mo,
                                       lastPeriodDate: lastPeriodDate)
            .subscribe(onSuccess: { }, onFailure: { [weak self] error in
                guard let self = self, let presenter = self.activityPresenter else { return }
                self.navigator.handleError(error: error, presenter: presenter)
            }).disposed(by: self.disposeBag)
    }

    // MARK: - Save & finish
    private func saveAllAndFinish() {
        guard let date = self.selectedDate,
              let flow = self.flowAmount,
              let related = self.periodRelated else {
            completionCallback()
            return
        }

        let data = DiaryNoteMenstrualData(
            date: date,
            flowAmount: flow,
            periodRelated: related,
            periodRelatedExplanation: self.periodRelatedExplanation,
            note: self.note,
            fromChart: variant.isFromChart,
            diaryNote: variant.chartDiaryNote
        )

        self.repository.sendDiaryNoteMenstrual(data: data)
            .flatMap { [weak self] diaryNote -> Single<DiaryNoteItem> in
                // FUAM-2932: when launched from the pinned feed alert, ack the
                // task so the BE drops the card. Errors here are logged but do
                // not roll back the diary note; the next feed refresh recovers.
                guard let self = self, let feedTaskId = self.feedTaskId else {
                    return .just(diaryNote)
                }
                let resultData = TaskNetworkResult(
                    data: ["diary_note_id": diaryNote.id],
                    attachedFile: nil
                )
                return self.repository
                    .sendTaskResult(taskId: feedTaskId, taskResult: resultData)
                    .map { diaryNote }
                    .catchAndReturn(diaryNote)
            }
            .addProgress()
            .subscribe(onSuccess: { [weak self] diaryNote in
                guard let self = self else { return }
                self.showSuccessPage(diaryNote: diaryNote)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                if let presenter = self.activityPresenter {
                    self.navigator.handleError(error: error, presenter: presenter)
                }
            }).disposed(by: self.disposeBag)
    }

    private func showSuccessPage(diaryNote: DiaryNoteItem) {
        let vc = MenstrualEntrySuccessViewController(diaryNote: diaryNote,
                                                     completion: self.completionCallback)
        vc.modalPresentationStyle = .fullScreen
        navigationController.pushViewController(vc, animated: true)
    }
}

// MARK: - MenstrualWhenViewControllerDelegate
extension MenstrualEntryCoordinator: MenstrualWhenViewControllerDelegate {
    func menstrualWhenViewController(_ vc: MenstrualWhenViewController,
                                     didSelect when: MenstrualWhenViewController.WhenChoice) {
        switch when {
        case .today:
            // Skip the date picker entirely.
            self.selectedDate = Date()
            pushFlowStep()
        case .earlier:
            let dateVC = MenstrualDateViewController(variant: variant)
            dateVC.delegate = self
            dateVC.alert = self.alert
            navigationController.pushViewController(dateVC,
                                                    hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                    animated: true)
        }
    }

    func menstrualWhenViewControllerDidCancel(_ vc: MenstrualWhenViewController) {
        completionCallback()
    }
}

// MARK: - Baseline onboarding step 1 delegate (FUAM-3243)
extension MenstrualEntryCoordinator: MenstrualOnboardingPeriod3MoViewControllerDelegate {
    func menstrualOnboardingPeriod3MoViewController(_ vc: MenstrualOnboardingPeriod3MoViewController,
                                                    didSelect value: MenstrualHadPeriod3Mo) {
        self.baselineHadPeriod3Mo = value
        switch value {
        case .no:
            // No period in the past 3 months → skip the date question.
            saveBaselineThenStartWizard(lastPeriodDate: nil)
        case .yes, .unsure:
            let lastPeriodVC = MenstrualOnboardingLastPeriodViewController()
            lastPeriodVC.delegate = self
            navigationController.pushViewController(lastPeriodVC, animated: true)
        }
    }

    func menstrualOnboardingPeriod3MoViewControllerDidCancel(_ vc: MenstrualOnboardingPeriod3MoViewController) {
        completionCallback()
    }
}

// MARK: - Baseline onboarding step 2 delegate (FUAM-3243)
extension MenstrualEntryCoordinator: MenstrualOnboardingLastPeriodViewControllerDelegate {
    func menstrualOnboardingLastPeriodViewController(_ vc: MenstrualOnboardingLastPeriodViewController,
                                                     didSelect date: Date) {
        saveBaselineThenStartWizard(lastPeriodDate: date)
    }
}

// MARK: - MenstrualDateViewControllerDelegate
extension MenstrualEntryCoordinator: MenstrualDateViewControllerDelegate {
    func menstrualDateViewController(_ vc: MenstrualDateViewController, didSelect date: Date) {
        self.selectedDate = date
        pushFlowStep()
    }
}

// MARK: - Step transitions

private extension MenstrualEntryCoordinator {
    func pushFlowStep() {
        let flowVC = MenstrualFlowViewController(variant: variant)
        flowVC.delegate = self
        flowVC.alert = self.alert
        navigationController.pushViewController(flowVC,
                                                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                animated: true)
    }

    func pushPeriodRelatedStep() {
        let relatedVC = MenstrualPeriodRelatedViewController(variant: variant)
        relatedVC.delegate = self
        relatedVC.alert = self.alert
        navigationController.pushViewController(relatedVC,
                                                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                animated: true)
    }

    func pushExplainStep() {
        let explainVC = MenstrualExplainViewController(variant: variant)
        explainVC.delegate = self
        explainVC.alert = self.alert
        navigationController.pushViewController(explainVC,
                                                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                animated: true)
    }

    func pushNoteStep() {
        let noteVC = MenstrualNoteViewController(variant: variant)
        noteVC.delegate = self
        noteVC.alert = self.alert
        navigationController.pushViewController(noteVC,
                                                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                animated: true)
    }
}

// MARK: - MenstrualFlowViewControllerDelegate
extension MenstrualEntryCoordinator: MenstrualFlowViewControllerDelegate {
    func menstrualFlowViewController(_ vc: MenstrualFlowViewController,
                                     didSelect flow: MenstrualFlowAmount) {
        self.flowAmount = flow
        pushPeriodRelatedStep()
    }
}

// MARK: - MenstrualPeriodRelatedViewControllerDelegate
extension MenstrualEntryCoordinator: MenstrualPeriodRelatedViewControllerDelegate {
    func menstrualPeriodRelatedViewController(_ vc: MenstrualPeriodRelatedViewController,
                                              didSelect related: MenstrualPeriodRelated) {
        self.periodRelated = related
        // "Let me explain" introduces an extra free-text step before the
        // standard final note. All other answers go straight to the note.
        if related == .letMeExplain {
            pushExplainStep()
        } else {
            pushNoteStep()
        }
    }
}

// MARK: - MenstrualExplainViewControllerDelegate
extension MenstrualEntryCoordinator: MenstrualExplainViewControllerDelegate {
    func menstrualExplainViewController(_ vc: MenstrualExplainViewController,
                                        didFinishWith explanation: String?) {
        self.periodRelatedExplanation = explanation
        pushNoteStep()
    }
}

// MARK: - MenstrualNoteViewControllerDelegate
extension MenstrualEntryCoordinator: MenstrualNoteViewControllerDelegate {
    func menstrualNoteViewController(_ vc: MenstrualNoteViewController,
                                     didFinishWithNote note: String?) {
        self.note = note
        saveAllAndFinish()
    }
}
