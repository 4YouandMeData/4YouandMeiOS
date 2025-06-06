//
//  WeHaveNoticedCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 05/06/25.
//
import RxSwift

enum FlowVariant {
    case standalone
    case embeddedInNoticed
}

/// Coordinator for the “We Have Noticed” flow, embedding the existing
/// InsulinEntryCoordinator as the first step.
final class WeHaveNoticedCoordinator: PagedActivitySectionCoordinator {

    var hidesBottomBarWhenPushed: Bool = false
        
    // MARK: – ActivitySectionCoordinator requirements
    let repository: Repository
    let navigator: AppNavigator
    let taskIdentifier: String
    let disposeBag = DisposeBag()
    var activityPresenter: UIViewController? { activitySectionViewController }
    var completionCallback: NotificationCallback

    var pages: [Page] { pagedSectionData.pages }
    var addAbortOnboardingButton: Bool = false
    
    var activitySectionViewController: ActivitySectionViewController?
    let pagedSectionData: PagedSectionData
    let coreViewController: UIViewController? = nil
    var currentlyRescheduledTimes: Int = 0
    let maxRescheduleTimes: Int = 0
    
    private var currentActivityCoordinator: ActivitySectionCoordinator?
        
    var navigationController: UINavigationController {
        guard let nav = activitySectionViewController?.internalNavigationController else {
            fatalError("ActivitySectionViewController not initialized")
        }
        return nav
    }
    
//    private var answeredDose: (type: String, date: Date, amount: Double)?
//    private var answeredFood: (didEat: Bool, mealType: String?, date: Date?, quantity: String?, hasNutrients: Bool?)?
    private var answeredActivity: PhysicalActivityViewController.ActivityLevel?
    private var answeredStress: StressLevelViewController.StressLevel?

    // MARK: – Initialization

    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         presenter: UIViewController,
         completion: @escaping NotificationCallback) {

        self.repository = repository
        self.navigator = navigator
        self.taskIdentifier = taskIdentifier
        self.completionCallback = completion
        
        self.pagedSectionData = PagedSectionData(
            welcomePage: Page(id: "wehaventiced_intro", type: "", title: "", body: "", image: nil),
                    successPage: nil,
                    pages: []
                )
    }

    // MARK: – Coordinator

    /// Returns the root UIViewController for this flow. If the presenter is not a UINavigationController,
    /// this method creates one internally, embeds the insulin‐entry flow, and returns it.
    func getStartingPage() -> UIViewController {
        
        let introVC = NoticedIntroViewController()
        introVC.delegate = self
        
        let activityVC = ActivitySectionViewController(coordinator: self,
                                                        startingViewController: introVC)
        self.activitySectionViewController = activityVC
        return activityVC
    }
}

extension WeHaveNoticedCoordinator: NoticedIntroViewControllerDelegate {
    
    func noticedIntroViewControllerDidSelectYes(_ vc: NoticedIntroViewController) {
        
        let insulinCompletion: NotificationCallback = { [weak self] in
            guard let self = self else { return }
            self.showFoodIntro()
        }
        
        let insulinCoordinator = InsulinEntryCoordinator(
            repository: repository,
            navigator: navigator,
            variant: .embeddedInNoticed,
            taskIdentifier: "insulinEntry",
            completion: insulinCompletion
        )
        
        self.currentActivityCoordinator = insulinCoordinator

        let startVC = insulinCoordinator.getStartingPage()
        vc.navigationController?.pushViewController(startVC, animated: true)
    }
    
    func noticedIntroViewControllerDidSelectNo(_ vc: NoticedIntroViewController) {
        showFoodIntro()
    }
    
    /// Called when user taps “Close” / cancella dal NoticedIntro
    func noticedIntroViewControllerDidCancel(_ vc: NoticedIntroViewController) {
        completionCallback()
    }
    
    /// Private helper: sposta al FoodIntro
    private func showFoodIntro() {
        let foodIntroVC = EatenIntroViewController()
        foodIntroVC.delegate = self
        
        navigationController.pushViewController(
            foodIntroVC,
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }
}

// MARK: – EatenIntroViewControllerDelegate

extension WeHaveNoticedCoordinator: EatenIntroViewControllerDelegate {
    
    func eatenIntroViewControllerDidSelectYes(_ vc: EatenIntroViewController) {
        let foodCompletion: NotificationCallback = { [weak self] in
            guard let self = self else { return }
            self.showPhysicalActivity()
        }
        
        let foodCoordinator = FoodEntryCoordinator(
            repository: repository,
            navigator: navigator,
            taskIdentifier: "foodEntry",
            variant: .embeddedInNoticed,
            completion: foodCompletion
        )
        
        self.currentActivityCoordinator = foodCoordinator
        
        navigationController.pushViewController(
            foodCoordinator.getStartingPage(),
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }

    func eatenIntroViewControllerDidSelectNo(_ vc: EatenIntroViewController) {
        showPhysicalActivity()
    }
    
    func eatenIntroViewControllerDidCancel(_ vc: EatenIntroViewController) {
        vc.navigationController?.popViewController(animated: true)
    }
    
    private func showPhysicalActivity() {
        let activityVC = PhysicalActivityViewController(variant: .embeddedInNoticed)
        activityVC.delegate = self
        
        navigationController.pushViewController(
            activityVC,
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }
}

// MARK: – PhysicalActivityViewControllerDelegate

extension WeHaveNoticedCoordinator: PhysicalActivityViewControllerDelegate {
    
    func physicalActivityViewController(_ vc: PhysicalActivityViewController,
                                        didSelect level: PhysicalActivityViewController.ActivityLevel) {
        self.answeredActivity = level
        
        let stressVC = StressLevelViewController(variant: .embeddedInNoticed)
        stressVC.delegate = self
        
        navigationController.pushViewController(
            stressVC,
            hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
            animated: true
        )
    }
    
    func physicalActivityViewControllerDidCancel(_ vc: PhysicalActivityViewController) {
        completionCallback()
    }
}

// MARK: – StressLevelViewControllerDelegate

extension WeHaveNoticedCoordinator: StressLevelViewControllerDelegate {
    
    func stressLevelViewController(_ vc: StressLevelViewController,
                                   didSelect level: StressLevelViewController.StressLevel) {
        self.answeredStress = level
        
        showSuccessPage()
    }
    
    /// Called quando l’utente annulla su StressLevel
    func stressLevelViewControllerDidCancel(_ vc: StressLevelViewController) {
        completionCallback()
    }
    
    private func showSuccessPage() {
        let successVC = SuccessViewController()
        
        successVC.onConfirm = { [weak self] in
            guard let self = self else { return }
            self.completionCallback()
        }
        
        successVC.modalPresentationStyle = .fullScreen
        activitySectionViewController?.present(successVC, animated: true, completion: nil)
    }
}
