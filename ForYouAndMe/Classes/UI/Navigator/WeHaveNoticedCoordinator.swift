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

struct FoodEntryData: Codable {
    let mealType: String
    let date: Date
    let quantity: String
    let hasNutrients: Bool
}

struct DoseEntryData: Codable {
    let doseType: String
    let date: Date
    let amount: Double
}

/// Coordinator for the “We Have Noticed” flow, embedding the existing
/// InsulinEntryCoordinator as the first step.
final class WeHaveNoticedCoordinator: PagedActivitySectionCoordinator {

    var hidesBottomBarWhenPushed: Bool = false
        
    // MARK: – ActivitySectionCoordinator requirements
    let repository: Repository
    let navigator: AppNavigator
    let cacheService: CacheService
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
    
    private var answeredDose: DoseEntryData?
    private var answeredFood: FoodEntryData?
    private var answeredActivity: PhysicalActivityViewController.ActivityLevel?
    private var answeredStress: StressLevelViewController.StressLevel?
    private var feed: Feed?
    private lazy var messages: [MessageInfo] = {
        let messages = self.cacheService.infoMessages?.messages(withLocation: .pageWeHaveNoticed)
        return messages ?? []
    }()

    // MARK: – Initialization

    init(repository: Repository,
         navigator: AppNavigator,
         taskIdentifier: String,
         presenter: UIViewController,
         feed: Feed,
         completion: @escaping NotificationCallback) {

        self.repository = repository
        self.navigator = navigator
        self.cacheService = Services.shared.storageServices
        self.taskIdentifier = taskIdentifier
        self.completionCallback = completion
        self.feed = feed
        
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
        
        let introVC = NoticedIntroViewController(navigator: self.navigator)
        introVC.delegate = self
        introVC.messages = self.messages
        
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
        
        let onDataCompletion: InsulinDataCallback = { [weak self] type, date, amount in
            self?.answeredDose = DoseEntryData(doseType: type, date: date, amount: amount)
        }
        
        let insulinCoordinator = InsulinEntryCoordinator(
            repository: repository,
            navigator: navigator,
            variant: .embeddedInNoticed,
            taskIdentifier: "insulinEntry",
            onData: onDataCompletion,
            completion: insulinCompletion
        )
        
        insulinCoordinator.messages = self.messages
        
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
        
        let onDataCallback: FoodDataCallback = { [weak self] mealType, snackDate, quantity, hasNutrient in
            self?.answeredFood = FoodEntryData(mealType: mealType,
                                               date: snackDate,
                                               quantity: quantity,
                                               hasNutrients: hasNutrient)
        }
        
        let foodCoordinator = FoodEntryCoordinator(
            repository: repository,
            navigator: navigator,
            taskIdentifier: "foodEntry",
            variant: .embeddedInNoticed,
            onDataCallback: onDataCallback,
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
        if let tv = feed?.extractWeHaveNoticedTemplateValues() {
            let diaryNoteData = DiaryNoteWeHaveNoticedItem(diaryType: .weNoticed,
                                                           dosesData: self.answeredDose,
                                                           foodData: self.answeredFood,
                                                           diaryDate: Date(),
                                                           answeredActivity: self.answeredActivity,
                                                           answeredStress: self.answeredStress,
                                                           oldValue: tv.oldValue,
                                                           oldValueRetrievedAt: tv.oldValueRetrievedAt,
                                                           currentValue: tv.currentValue,
                                                           currentValueRetrievedAt: tv.currentValueRetrievedAt)
            
            self.repository.sendCombinedDiaryNote(diaryNote: diaryNoteData)
                .addProgress()
                .subscribe(onSuccess: { [weak self] _ in
                    self?.showSuccessPage()
                }, onFailure: { _ in
                    // handle error if needed
                })
                .disposed(by: disposeBag)
        }
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
