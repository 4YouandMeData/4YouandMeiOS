//
//  MenstrualEntryCoordinator.swift
//  ForYouAndMe
//
//  FUAM-2935 — Drives the 5-step menstrual cycle diary wizard.
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
    private var selectedDate: Date?
    private var flowAmount: MenstrualFlowAmount?
    private var periodRelated: MenstrualPeriodRelated?
    private var note: String?

    // MARK: - Initialization
    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         variant: FlowVariant,
         completion: @escaping NotificationCallback) {
        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
        self.variant = variant
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
        let whenVC = MenstrualWhenViewController(variant: variant)
        whenVC.delegate = self
        whenVC.alert = self.alert

        let activityVC = ActivitySectionViewController(coordinator: self,
                                                       startingViewController: whenVC)
        self.activitySectionViewController = activityVC
        return activityVC
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
            note: self.note,
            fromChart: variant.isFromChart,
            diaryNote: variant.chartDiaryNote
        )

        self.repository.sendDiaryNoteMenstrual(data: data)
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
