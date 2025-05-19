//
//  DosesEntryCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 19/05/25.
//

import UIKit
import RxSwift

/// Coordinator for the “Add a dose” flow
final class InsulinEntryCoordinator: PagedActivitySectionCoordinator {
    
    // MARK: – Coordinator requirements
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: – ActivitySectionCoordinator requirements
    let repository: Repository
    let navigator: AppNavigator
    let taskIdentifier: String
    let disposeBag = DisposeBag()
    var activityPresenter: UIViewController? { activitySectionViewController }
    var completionCallback: NotificationCallback
    
    // MARK: – PagedSectionCoordinator requirements
    var pages: [Page] { pagedSectionData.pages }
    var addAbortOnboardingButton: Bool = false
    var navigationController: UINavigationController {
        guard let nav = activitySectionViewController?.internalNavigationController else {
            fatalError("ActivitySectionViewController not initialized")
        }
        return nav
    }
    
    // MARK: – PagedActivitySectionCoordinator requirements
    var activitySectionViewController: ActivitySectionViewController?
    let pagedSectionData: PagedSectionData
    let coreViewController: UIViewController? = nil
    var currentlyRescheduledTimes: Int = 0
    let maxRescheduleTimes: Int = 0
    
    // MARK: – Collected data
    private var selectedDoseTypeText: String?
    private var selectedDoseType: String?
    private var doseDate: Date?
    private var doseAmount: Double?
    
    // MARK: – Initialization
    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         completion: @escaping NotificationCallback) {
        
        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
        self.completionCallback = completion
        
        // Define the sequence of pages
        let sequence: [Page] = [
            .doseType,
            .doseDateTime,
            .doseAmount
        ]
        self.pagedSectionData = PagedSectionData(
            welcomePage: sequence[0],
            successPage: nil,
            pages: sequence
        )
    }
    
    // MARK: – Flow start
    func getStartingPage() -> UIViewController {
        let vc = DoseTypeViewController()
        vc.delegate = self
        
        self.activitySectionViewController =
          ActivitySectionViewController(coordinator: self,
                                        startingViewController: vc)
        return activitySectionViewController!
    }
    
    // MARK: – Save & finish
    private func saveAllAndFinish() {
        // Perform the API call with collected data
        guard let type = selectedDoseType,
              let date = doseDate,
              let amount = doseAmount else {
            completionCallback()
            return
        }
        
        repository.sendDiaryNoteDoses(
            doseType: type,
            date: date,
            amount: amount,
            fromChart: false
        )
        .addProgress()
        .subscribe(onSuccess: { [weak self] _ in
            self?.completionCallback()
        }, onFailure: { error in
            // handle error if needed
        })
        .disposed(by: disposeBag)
    }
}

// MARK: – DoseTypeViewControllerDelegate
extension InsulinEntryCoordinator: DoseTypeViewControllerDelegate {
    func doseTypeViewController(_ vc: DoseTypeViewController, didSelect type: DoseTypeViewController.DoseType) {
        selectedDoseTypeText = type.displayText
        selectedDoseType = type.rawValue
        
        guard let selectedDoseType = self.selectedDoseType else {
            fatalError("Selected dose type is nil")
        }
        
        // Navigate to date/time selector
        let dtVC = DoseDateTimeViewController(displayTitle: selectedDoseType)
        dtVC.delegate = self
        navigationController.pushViewController(
            dtVC,
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }
    
    func doseTypeViewControllerDidCancel(_ vc: DoseTypeViewController) {
        completionCallback()
    }
}

// MARK: – DoseDateTimeViewControllerDelegate
extension InsulinEntryCoordinator: DoseDateTimeViewControllerDelegate {
    func doseDateTimeViewController(_ vc: DoseDateTimeViewController, didSelect date: Date, amount: Double) {
        // collect both values and fire save
        doseDate   = date
        doseAmount = amount
        saveAllAndFinish()
    }

    func doseDateTimeViewControllerDidCancel(_ vc: DoseDateTimeViewController) {
        completionCallback()
    }
}
