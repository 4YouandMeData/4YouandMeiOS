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
    case fromChart(diaryNote: DiaryNoteItem)
}

// MARK: - FlowVariant helpers
extension FlowVariant {
    /// true for `.fromChart(_)`
    var isFromChart: Bool {
        if case .fromChart = self { return true }
        return false
    }

    /// Unwraps the associated note when `.fromChart`
    var chartDiaryNote: DiaryNoteItem? {
        if case let .fromChart(note) = self { return note }
        return nil
    }

    /// Treat `.fromChart` like standalone for UI copy, messages, buttons
    var isStandaloneLike: Bool {
        switch self {
        case .standalone, .fromChart: return true
        case .embeddedInNoticed:      return false
        }
    }

    /// Convenience flag
    var isEmbeddedInNoticed: Bool {
        if case .embeddedInNoticed = self { return true }
        return false
    }
}

struct FoodEntryData: Codable {
    let mealType: String
    let date: Date
    let quantity: String
    let hasNutrients: Bool
}

struct DoseEntryData: Codable {
    let doseType: String
    let date: Date?
    let amount: Double
}

/// The possible activity levels the user can choose
enum ActivityLevel: String, Codable {
    case no        = "no"
    case mild      = "mild"
    case moderate  = "moderate"
    case vigorous  = "vigouros"
    
    /// Returns the localized display text for each activity level
    var displayText: String {
        switch self {
        case .no:
            return StringsProvider.string(forKey: .noticedStepTenFirstButton)
        case .mild:
            return StringsProvider.string(forKey: .noticedStepTenSecondButton)
        case .moderate:
            return StringsProvider.string(forKey: .noticedStepTenThirdButton)
        case .vigorous:
            return StringsProvider.string(forKey: .noticedStepTenFourthButton)
        }
    }
    
    /// Returns the name of the icon image (template) for each level
    var iconImageName: TemplateImageName {
        switch self {
        case .no:
            return .activityIconNo
        case .mild:
            return .activityIconMild
        case .moderate:
            return .activityIconModerate
        case .vigorous:
            return .activityIconVigorous
        }
    }
}

/// The possible stress levels the user can choose
enum StressLevel: String, Codable {
    case none         = "not_stressed_at_all"
    case aLittle      = "a_little_stressed"
    case somewhat     = "somewhat_stressed"
    case stressed     = "stressed"
    case veryStressed = "very_stressed"
    
    /// Returns the localized display text for each stress level
    var displayText: String {
        switch self {
        case .none:
            return StringsProvider.string(forKey: .noticedStepElevenFirstButton)
        case .aLittle:
            return StringsProvider.string(forKey: .noticedStepElevenSecondButton)
        case .somewhat:
            return StringsProvider.string(forKey: .noticedStepElevenThirdButton)
        case .stressed:
            return StringsProvider.string(forKey: .noticedStepElevenFourthButton)
        case .veryStressed:
            return StringsProvider.string(forKey: .noticedStepElevenFifthButton)
        }
    }
    
    /// Returns the name of the icon image (template) for each level
    var iconImageName: TemplateImageName {
        switch self {
        case .none:
            return .stressIconNone
        case .aLittle:
            return .stressIconLittle
        case .somewhat:
            return .stressIconSome
        case .stressed:
            return .stressIconStressed
        case .veryStressed:
            return .stressIconVeryStressed
        }
    }
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
    private var answeredActivity: ActivityLevel?
    private var answeredStress: StressLevel?
    private var feed: Feed
    private var alert: Alert
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
         alert: Alert,
         completion: @escaping NotificationCallback) {

        self.repository = repository
        self.navigator = navigator
        self.cacheService = Services.shared.storageServices
        self.taskIdentifier = taskIdentifier
        self.completionCallback = completion
        self.feed = feed
        self.alert = alert
        
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
        
        let introVC = NoticedIntroViewController(alert: self.alert,
                                                 navigator: self.navigator)
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
        insulinCoordinator.alert = self.alert
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
        foodIntroVC.alert = self.alert
        
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
        foodCoordinator.alert = self.alert
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
        activityVC.alert = self.alert
        
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
                                        didSelect level: ActivityLevel) {
        self.answeredActivity = level
        
        let stressVC = StressLevelViewController(variant: .embeddedInNoticed)
        stressVC.delegate = self
        stressVC.alert = self.alert
        
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
                                   didSelect level: StressLevel) {
        self.answeredStress = level
        if let tv = feed.extractWeHaveNoticedTemplateValues() {
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
                .flatMap { diaryNoteItem -> Single<DiaryNoteItem> in
                    let resultData: TaskNetworkResult = TaskNetworkResult(data: [
                        "diary_note_id": diaryNoteItem.id
                    ], attachedFile: nil)
                    return self.repository.sendTaskResult(taskId: self.taskIdentifier, taskResult: resultData).map { diaryNoteItem }
                }
                .subscribe(onSuccess: { [weak self] diaryNote in
                    guard let self = self else { return }
                    self.showSuccessPage(with: diaryNote)
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
    
    private func showSuccessPage(with diaryNote: DiaryNoteItem) {
        let successVC = WeNoticedSuccessViewController(diaryNote: diaryNote) {
            self.completionCallback()
        }
        
        successVC.modalPresentationStyle = .fullScreen
        activitySectionViewController?.present(successVC, animated: true, completion: nil)
    }
}
