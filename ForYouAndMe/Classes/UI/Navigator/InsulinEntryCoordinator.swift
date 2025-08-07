//
//  DosesEntryCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 19/05/25.
//

import UIKit
import RxSwift

/// Available dose types
enum DoseType: String, Codable {
    case pumpBolus        = "bolus_dose"
    case insulinInjection = "insulin_injection"
    
    /// The actual text shown on screen
    func displayText(usingVariant variant: FlowVariant) -> String {
        
        switch variant {
        case .standalone:
            switch self {
            case .pumpBolus:
                return StringsProvider.string(forKey: .doseStepOneFirstButton)
            case .insulinInjection:
                return StringsProvider.string(forKey: .doseStepOneSecondButton)
            }
            
        case .embeddedInNoticed:
            switch self {
            case .pumpBolus:
                return StringsProvider.string(forKey: .noticedStepTwoFirstButton)
            case .insulinInjection:
                return StringsProvider.string(forKey: .noticedStepTwoSecondButton)
            }
        }
    }
}

/// Coordinator for the “Add a dose” flow
final class InsulinEntryCoordinator: PagedActivitySectionCoordinator {
    
    // MARK: – Coordinator requirements
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: – ActivitySectionCoordinator requirements
    let repository: Repository
    let navigator: AppNavigator
    var messages: [MessageInfo] = []
    var alert: Alert?
    let taskIdentifier: String
    let disposeBag = DisposeBag()
    var activityPresenter: UIViewController? { activitySectionViewController }
    var onData: InsulinDataCallback?
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
    private let variant: FlowVariant
    
    // MARK: – Collected data
    private var selectedDoseTypeText: String?
    private var selectedDoseType: String?
    private var doseDate: Date?
    private var doseAmount: Double?
    
    // MARK: – Initialization
    init(repository: Repository,
         navigator: AppNavigator,
         variant: FlowVariant,
         taskIdentifier: String,
         externalNavigationController: UINavigationController? = nil,
         onData: @escaping InsulinDataCallback,
         completion: @escaping NotificationCallback) {
        
        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
        self.completionCallback = completion
        self.onData = onData
        self.variant = variant
        
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
        
        switch variant {
        case .standalone:
            let vc = DoseTypeViewController(variant: self.variant)
            vc.delegate = self
            
            self.activitySectionViewController =
              ActivitySectionViewController(coordinator: self,
                                            startingViewController: vc)
            return activitySectionViewController!
        case .embeddedInNoticed:
            let doseTypeVC = DoseTypeViewController(variant: self.variant)
            doseTypeVC.delegate = self
            doseTypeVC.alert = self.alert
            return doseTypeVC
        }
        
    }
    
    // MARK: – Save & finish
    private func saveAllAndFinish() {
        // Perform the API call with collected data
        guard let type = selectedDoseType,
              let amount = doseAmount else {
            completionCallback()
            return
        }
        
        if variant == .embeddedInNoticed {
            onData?(type, nil, amount)
            self.completionCallback()
        } else {
            
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
            .subscribe(onSuccess: { [weak self] diaryNote in
                guard let self = self else { return }
                self.showSuccessPage(diaryNote: diaryNote)   
            }, onFailure: { _ in
                // handle error if needed
            })
            .disposed(by: disposeBag)
        }
    }
    
    private func showSuccessPage(diaryNote: DiaryNoteItem) {
        let vc = InsulinEntrySuccessViewController(diaryNote: diaryNote,
                                                completion: self.completionCallback)
        vc.modalPresentationStyle = .fullScreen
        navigationController.pushViewController(vc, animated: true)
    }
}

// MARK: – DoseTypeViewControllerDelegate
extension InsulinEntryCoordinator: DoseTypeViewControllerDelegate {
    func doseTypeViewController(_ vc: DoseTypeViewController, didSelect type: DoseType) {
        selectedDoseTypeText = type.displayText(usingVariant: self.variant)
        selectedDoseType = type.rawValue
        
        guard self.selectedDoseType != nil,
              let selectedDoseTypeText = self.selectedDoseTypeText else {
            fatalError("Selected dose type is nil")
        }
        
        let dtVC = DoseDateTimeViewController(displayTitle: selectedDoseTypeText, variant: variant)
        dtVC.delegate = self
        dtVC.alert = self.alert
        if variant == .embeddedInNoticed {
            vc.navigationController?.pushViewController(
                dtVC,
                animated: true
            )
        } else {
            // Se sono nel diary standalone, uso il navigationController interno di ActivitySectionViewController
            navigationController.pushViewController(
                dtVC,
                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                animated: true
            )
        }
    }
    
    func doseTypeViewControllerDidCancel(_ vc: DoseTypeViewController) {
        if let presenter = activitySectionViewController {
            presenter.dismiss(animated: true, completion: nil)
        }
        completionCallback()
    }
}

// MARK: – DoseDateTimeViewControllerDelegate
extension InsulinEntryCoordinator: DoseDateTimeViewControllerDelegate {
    func doseDateTimeViewController(_ vc: DoseDateTimeViewController, didSelect date: Date?, amount: Double) {
        // collect both values and fire save
        doseDate   = date
        doseAmount = amount
        saveAllAndFinish()
    }

    func doseDateTimeViewControllerDidCancel(_ vc: DoseDateTimeViewController) {
        if let presenter = activitySectionViewController {
            presenter.dismiss(animated: true, completion: nil)
        }
        completionCallback()
    }
}
