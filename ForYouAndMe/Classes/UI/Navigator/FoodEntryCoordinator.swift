//
//  FoodEntryCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 14/05/25.
//

import UIKit
import RxSwift

final class FoodEntryCoordinator: PagedActivitySectionCoordinator {
    
    // MARK: - Coordinator requirements
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: - ActivitySectionCoordinator requirements
    let repository: Repository
    let navigator: AppNavigator
    let taskIdentifier: String
    let disposeBag = DisposeBag()
    var activityPresenter: UIViewController? { activitySectionViewController }
    var completionCallback: NotificationCallback
    
    // MARK: - PagedSectionCoordinator requirements
    /// Sequence of pages for the flow (no separate welcome/success)
    var pages: [Page] { pagedSectionData.pages }
    
    /// Option to show an abort button on pages
    var addAbortOnboardingButton: Bool = false
    
    /// Navigation controller driving the paged UI
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
    private var selectedFoodType: String?
    private var snackDate: Date?
    private var quantitySelection: String?
    private var nutrientAnswer: Bool?
    
    // MARK: - Initialization
    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         completion: @escaping NotificationCallback) {
        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
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
        // Use custom view controller for first step
        let vc = EatenTypeViewController()
        vc.delegate = self
        
        self.activitySectionViewController = ActivitySectionViewController(coordinator: self, startingViewController: vc)
        return activitySectionViewController!
    }
    
    // MARK: - Save & finish
    private func saveAllAndFinish() {
        // Example saving logic
        print("Selected food type: \(selectedFoodType ?? "-")")
        print("Snack date: \(snackDate ?? Date())")
        print("Quantity: \(quantitySelection ?? "-")")
        print("Contains nutrients: \(nutrientAnswer == true ? "Yes" : "No")")
        completionCallback()
    }
}

extension FoodEntryCoordinator: EatenTypeViewControllerDelegate {
    func eatenTypeViewController(_ vc: EatenTypeViewController, didSelect type: EatenTypeViewController.EntryType) {
        selectedFoodType = type.rawValue
        
        guard let select = selectedFoodType else {
            return
        }
        
        // Navigate to time selection screen
        let timeVC = EatenTimeViewController(selectedType: EatenTypeViewController.EntryType(rawValue: select)!)
        timeVC.delegate = self
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
            
            let amountVC = ConsumptionAmountViewController()
            amountVC.selectedType = EatenTypeViewController.EntryType(rawValue: selectedFoodType!)!
            amountVC.delegate = self
            navigationController.pushViewController(
                amountVC,
                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                animated: true
            )
        } else {
            
            let dateTimeVC = EatenDateTimeViewController()
            dateTimeVC.selectedType = EatenTypeViewController.EntryType(rawValue: selectedFoodType!)!
            dateTimeVC.delegate = self
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
                                     didSelect type: EatenTypeViewController.EntryType,
                                     at date: Date) {
        // Save the chosen date/time
        snackDate = date
        
        // Move to the next step: quantity selection
        let amountVC = ConsumptionAmountViewController()
        amountVC.selectedType = type
        amountVC.delegate = self
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
        let nutrientVC = NutrientQuestionViewController()
        nutrientVC.selectedType = EatenTypeViewController.EntryType(rawValue: selectedFoodType!)!
        nutrientVC.delegate = self
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
        
        guard let snackDate = self.snackDate,
              let selectedFoodType = self.selectedFoodType,
              let quantitySelection = self.quantitySelection,
              let nutrientAnswer = self.nutrientAnswer else {
            return
        }
        
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
    
    func nutrientQuestionViewControllerDidCancel(_ vc: NutrientQuestionViewController) {
        completionCallback()
    }
}
