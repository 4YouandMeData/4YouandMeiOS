//
//  ReflectionSectionCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 07/04/25.
//

import RxSwift

protocol ReflectionViewCoordinator {
    func onReflectionCreated(presenter: UIViewController, reflectionType: DiaryNoteItemType, diaryNote: DiaryNoteItem)
}

class ReflectionSectionCoordinator: NSObject, PagedActivitySectionCoordinator {
    
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
    var coreViewController: UIViewController? { return makeReflectionViewController() }
    var headerImage: URL?
    
    let spirometryService: MirSpirometryService
    
    private let analytics: AnalyticsService
    
    init(withTask task: Feed,
         activity: Activity,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = task.id
        self.headerImage = activity.image
        self.pagedSectionData = activity.pagedSectionData
        self.currentlyRescheduledTimes = task.rescheduledTimes ?? 0
        self.maxRescheduleTimes = activity.rescheduleTimes ?? 0
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        
        self.spirometryService = Services.shared.mirSpirometryService
        self.spirometryService.enableBluetooth()

        super.init()
        
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.videoDiary.rawValue,
                                                  screenClass: String(describing: type(of: self))))
    }
    
    deinit {
        print("SpyrometerSectionCoordinator - deinit")
        self.deleteTaskResult()
    }
    
    // MARK: - Public Methods
    
    public func onCancelTask() {
        self.navigationController.popViewController(animated: true)
    }
    
    // MARK: - Private Methods
    
    private func deleteTaskResult() {
        try? FileManager.default.removeItem(atPath: Constants.Task.SpyrometerResultURL.path)
    }
    
    // MARK: - Flow Management Methods
        
    /// Pushes the test view controller after a successful device connection.
    private func showLearnModeViewController(title: String, body: String) {
        let learnMoreVC = FormSheetPage(title: title, body: body)
        learnMoreVC.modalPresentationStyle = .formSheet
        self.activityPresenter?.present(learnMoreVC, animated: true)
    }
    
    /// Pushes the results view controller to display the spirometry test results.
    private func sendResult(taskResult: [String: String], presenter: UIViewController) {
        
        self.repository.sendTaskResult(taskId: self.taskIdentifier,
                                       taskResult: TaskNetworkResult(data: taskResult, attachedFile: nil))
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                 self.showSuccessPage()
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                
                self.navigator.handleError(
                    error: error,
                    presenter: presenter,
                    onDismiss: {},
                    onRetry: { [weak self] in
                        self?.sendResult(taskResult: taskResult, presenter: presenter)
                    },
                    dismissStyle: .destructive
                )
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Building Child View Controllers
        
    /// Creates the scan view controller which manages device discovery and connection.
    /// When a device is successfully connected, the view controller triggers the onScanCompleted callback.
    private func makeReflectionViewController() -> UIViewController {
        let reflectionVC = ReflectionViewController(headerImage: self.headerImage)
        reflectionVC.onLearnMorePressed = { [weak self] title, body in
            self?.showLearnModeViewController(title: title, body: body)
        }
        
        reflectionVC.onWritePressed = { [weak self] in
            guard let self = self else { return }
            let diaryNoteable = DiaryNoteable(id: self.taskIdentifier, type: "Task")
            let dataPoint = DiaryNoteItem(diaryNoteId: self.taskIdentifier,
                                          body: nil,
                                          interval: nil,
                                          diaryNoteable: diaryNoteable)
            let diaryNoteTextViewController = DiaryNoteTextViewController(withDataPoint: dataPoint,
                                                                          isEditMode: false,
                                                                          isFromChart: false,
                                                                          reflectionCoordinator: self)
            
            self.activityPresenter?.view.backgroundColor = ColorPalette.color(withType: .secondary)
            self.navigationController.pushViewController(diaryNoteTextViewController,
                                                         hidesBottomBarWhenPushed: false,
                                                         animated: true)
        }
        
        reflectionVC.onAudioPressed = { [weak self] in
            guard let self = self else { return }
            let diaryNoteable = DiaryNoteable(id: self.taskIdentifier, type: "Task")
            let dataPoint = DiaryNoteItem(diaryNoteId: self.taskIdentifier,
                                          body: nil,
                                          interval: nil,
                                          diaryNoteable: diaryNoteable)
            let diaryNoteAudioViewController = DiaryNoteAudioViewController(withDiaryNote: dataPoint,
                                                                            isEditMode: false,
                                                                            reflectionCoordinator: self)
            
            self.activityPresenter?.view.backgroundColor = ColorPalette.color(withType: .secondary)
            self.navigationController.pushViewController(diaryNoteAudioViewController,
                                                         hidesBottomBarWhenPushed: false,
                                                         animated: true)
        }
        
        reflectionVC.onVideoPressed = { [weak self] in
            guard let self = self else { return }
            let diaryNoteable = DiaryNoteable(id: self.taskIdentifier, type: "Task")
            let dataPoint = DiaryNoteItem(diaryNoteId: self.taskIdentifier,
                                          body: nil,
                                          interval: nil,
                                          diaryNoteable: diaryNoteable)
            let diaryNoteVideoViewController = DiaryNoteVideoViewController(diaryNoteItem: dataPoint,
                                                                            isEdit: false,
                                                                            reflectionCoordinator: self)
            
            self.activityPresenter?.view.backgroundColor = ColorPalette.color(withType: .secondary)
            self.navigationController.pushViewController(diaryNoteVideoViewController,
                                                         hidesBottomBarWhenPushed: false,
                                                         animated: true)
        }

        return reflectionVC
    }
    
    // MARK: - Navigation Helpers
        
    /// Returns the internal navigation controller from the activitySectionViewController.
    var navigationController: UINavigationController {
        guard let nav = self.activitySectionViewController?.internalNavigationController else {
            assertionFailure("No internal navigation controller found.")
            return UINavigationController()
        }
        return nav
    }
    
    /// Convenience property for presenting alerts or handling errors.
    var activityPresenter: UIViewController? {
        return self.activitySectionViewController
    }
}

extension ReflectionSectionCoordinator: ReflectionViewCoordinator {
    func onReflectionCreated(presenter: UIViewController, reflectionType: DiaryNoteItemType, diaryNote: DiaryNoteItem) {
        let diaryNoteDict: [String: String] = [
            "id": diaryNote.id
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: diaryNoteDict, options: []),
              let diaryNoteJSONString = String(data: jsonData, encoding: .utf8) else {
            // In caso di errore, puoi decidere come gestirlo (ad esempio, inviare un dizionario vuoto)
            self.sendResult(taskResult: [:], presenter: presenter)
            return
        }
        
        let taskResultData: [String: String] = [
            "diary_note": diaryNoteJSONString
        ]
        switch reflectionType {
        case .audio:
            self.sendResult(taskResult: taskResultData, presenter: presenter)
            return
        case .video:
            self.sendResult(taskResult: taskResultData, presenter: presenter)
            return
        case .text:
            self.sendResult(taskResult: taskResultData, presenter: presenter)
            return
        case .eaten, .doses:
            return
        }
    }
}
