//
//  FoodEntryCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 14/05/25.
//

import UIKit
import RxSwift

enum FoodEntryType: String {
    case snack
    case meal
    
    func displayTextUsingVariant(variant: FlowVariant) -> String {
        switch variant {
        case .embeddedInNoticed:
            switch self {
            case .snack: return StringsProvider.string(forKey: .noticedStepFiveFirstButton)
            case .meal:  return StringsProvider.string(forKey: .noticedStepFiveSecondButton)
            }
        case .standalone:
            switch self {
            case .snack: return StringsProvider.string(forKey: .diaryNoteEatenStepOneFirstButton)
            case .meal:  return StringsProvider.string(forKey: .diaryNoteEatenStepOneSecondButton)
            }
        }
        
    }
}

final class FoodEntryCoordinator: PagedActivitySectionCoordinator {
    
    // MARK: - “External” navigation controller (se passata)
    private weak var externalNavigationController: UINavigationController?
    
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
    var onDataCallback: FoodDataCallback?
    
    // MARK: - PagedSectionCoordinator requirements
    /// Sequence of pages for the flow (no separate welcome/success)
    var pages: [Page] { pagedSectionData.pages }
    
    /// Option to show an abort button on pages
    var addAbortOnboardingButton: Bool = false
    
    /// Navigation controller driving the paged UI
    var navigationController: UINavigationController {
        switch variant {
        case .embeddedInNoticed:
            guard let eatenVC = rootEatenTypeVC else {
                fatalError("rootEatenTypeVC is not initialized in embeddedInNoticed")
            }
            guard let nav = eatenVC.navigationController else {
                fatalError("not navcontroller")
            }
            return nav
            
        case .standalone:
            guard let nav = activitySectionViewController?.internalNavigationController else {
                fatalError("ActivitySectionViewController not initialized")
            }
            return nav
        }
    }
    
    // MARK: - PagedActivitySectionCoordinator requirements
    var activitySectionViewController: ActivitySectionViewController?
    let pagedSectionData: PagedSectionData
    let coreViewController: UIViewController? = nil
    var currentlyRescheduledTimes: Int = 0
    let maxRescheduleTimes: Int = 0
    
    // MARK: - Collected user data
    private var selectedFoodType: String?
    private var snackDate: Date?
    private var quantitySelection: String?
    private var nutrientAnswer: Bool?
    private let variant: FlowVariant
    private var rootEatenTypeVC: EatenTypeViewController?
    
    // MARK: - Initialization
    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         variant: FlowVariant,
         externalNavigationController: UINavigationController? = nil,
         onDataCallback: @escaping FoodDataCallback,
         completion: @escaping NotificationCallback) {
        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
        self.variant = variant
        self.externalNavigationController = externalNavigationController
        self.onDataCallback = onDataCallback
        self.completionCallback = completion
        
        // Build pages sequence: includes all steps, no dedicated welcome/success
        let sequence: [Page] = [
            .foodType,
            .timeRelative,
            .dateTime,
            .quantity,
            .nutrient,
            .confirm
        ]
        self.pagedSectionData = PagedSectionData(
            welcomePage: sequence[0],
            successPage: nil,
            pages: sequence
        )
    }
    
    // MARK: - Flow start
    func getStartingPage() -> UIViewController {
        switch variant {
        case .embeddedInNoticed:
            let eatenTypeVC = EatenTypeViewController(variant: variant)
            eatenTypeVC.delegate = self
            self.rootEatenTypeVC = eatenTypeVC
            eatenTypeVC.alert = self.alert
            return eatenTypeVC
            
        case .standalone:
            let eatenTypeVC = EatenTypeViewController(variant: variant)
            eatenTypeVC.delegate = self
            
            let activityVC = ActivitySectionViewController(coordinator: self,
                                                            startingViewController: eatenTypeVC)
            self.activitySectionViewController = activityVC
            return activityVC
        }
    }
    
    // MARK: - Save & finish
    private func saveAllAndFinish() {
        guard let snackDate = self.snackDate,
              let selectedFoodType = self.selectedFoodType,
              let quantitySelection = self.quantitySelection,
              let nutrientAnswer = self.nutrientAnswer else {
            return
        }
        
        if variant == .embeddedInNoticed {
            self.onDataCallback?(selectedFoodType, snackDate, quantitySelection, nutrientAnswer)
            self.completionCallback()
        } else {
            self.repository.sendDiaryNoteEaten(date: snackDate,
                                               mealType: selectedFoodType.lowercased(),
                                               quantity: quantitySelection,
                                               significantNutrition: nutrientAnswer,
                                               fromChart: true)
                .addProgress()
                .subscribe(onSuccess: { [weak self] _ in
                    guard let self = self else { return }
                    completionCallback()
                }, onFailure: { _ in
                    
                }).disposed(by: self.disposeBag)
        }
    }
}

extension FoodEntryCoordinator: EatenTypeViewControllerDelegate {
    func eatenTypeViewController(_ vc: EatenTypeViewController, didSelect type: FoodEntryType) {
        selectedFoodType = type.rawValue
        
        guard let select = selectedFoodType else {
            return
        }
        
        // Navigate to time selection screen
        let timeVC = EatenTimeViewController(selectedType: FoodEntryType(rawValue: select)!,
                                             variant: self.variant)
        timeVC.delegate = self
        timeVC.alert = self.alert
        navigationController.pushViewController(
            timeVC,
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }
    
    func eatenDismiss(_ vc: EatenTypeViewController) {
        completionCallback()
    }
}

extension FoodEntryCoordinator: EatenTimeViewControllerDelegate {
    func eatenTimeViewController(_ vc: EatenTimeViewController, didSelect relative: EatenTimeViewController.TimeRelative) {
        if relative == .withinHour {
            snackDate = Date()
            
            let amountVC = ConsumptionAmountViewController(variant: self.variant)
            amountVC.selectedType = FoodEntryType(rawValue: selectedFoodType!)!
            amountVC.delegate = self
            navigationController.pushViewController(
                amountVC,
                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                animated: true
            )
        } else {
            
            let dateTimeVC = EatenDateTimeViewController(variant: self.variant)
            dateTimeVC.selectedType = FoodEntryType(rawValue: selectedFoodType!)!
            dateTimeVC.delegate = self
            dateTimeVC.alert = self.alert
            navigationController.pushViewController(
                dateTimeVC,
                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                animated: true
            )
        }
    }
}

// MARK: – EatenDateTimeViewControllerDelegate
extension FoodEntryCoordinator: EatenDateTimeViewControllerDelegate {
    func eatenDateTimeViewController(_ vc: EatenDateTimeViewController,
                                     didSelect type: FoodEntryType,
                                     at date: Date) {
        // Save the chosen date/time
        snackDate = date
        
        // Move to the next step: quantity selection
        let amountVC = ConsumptionAmountViewController(variant: self.variant)
        amountVC.selectedType = type
        amountVC.delegate = self
        amountVC.alert = self.alert
        navigationController.pushViewController(
            amountVC,
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }
    
    func eatenDateTimeViewControllerDidCancel(_ vc: EatenDateTimeViewController) {
        // User tapped back – treat as abort
        completionCallback()
    }
}

// MARK: – ConsumptionAmountViewControllerDelegate
extension FoodEntryCoordinator: ConsumptionAmountViewControllerDelegate {
    func consumptionAmountViewController(_ vc: ConsumptionAmountViewController,
                                         didSelect amount: String) {
        quantitySelection = amount
        
        // Next: nutrient question screen
        let nutrientVC = NutrientQuestionViewController(variant: self.variant)
        nutrientVC.selectedType = FoodEntryType(rawValue: selectedFoodType!)!
        nutrientVC.delegate = self
        nutrientVC.alert = self.alert
        navigationController.pushViewController(
            nutrientVC,
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }
    
    func consumptionAmountViewControllerDidCancel(_ vc: ConsumptionAmountViewController) {
        completionCallback()
    }
}

// MARK: – NutrientQuestionViewControllerDelegate
extension FoodEntryCoordinator: NutrientQuestionViewControllerDelegate {
    func nutrientQuestionViewController(_ vc: NutrientQuestionViewController,
                                        didAnswer hasNutrients: Bool) {
        nutrientAnswer = hasNutrients
        
        self.saveAllAndFinish()
    }
    
    func nutrientQuestionViewControllerDidCancel(_ vc: NutrientQuestionViewController) {
        completionCallback()
    }
}
