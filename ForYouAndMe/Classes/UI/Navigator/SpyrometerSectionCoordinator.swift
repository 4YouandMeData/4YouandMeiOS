//
//  SpyrometerSectionCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 17/03/25.
//

import Foundation
import RxSwift
import MirSmartDevice

class SpyrometerSectionCoordinator: NSObject, PagedActivitySectionCoordinator {
    
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
    var coreViewController: UIViewController? { return makeScanViewController() }
    
    let spirometryService: MirSpirometryService
    
    private let analytics: AnalyticsService
    
    init(withTask task: Feed,
         activity: Activity,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = task.id
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
    
    public func onSpyroCompleted() {
        self.deleteTaskResult()
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.spyrometerComplete.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.showSuccessPage()
    }
    
    public func onCancelTask() {
        self.completionCallback()
    }
    
    // MARK: - Private Methods
    
    private func deleteTaskResult() {
        try? FileManager.default.removeItem(atPath: Constants.Task.SpyrometerResultURL.path)
    }
    
    // MARK: - Flow Management Methods
        
    /// Pushes the test view controller after a successful device connection.
    private func showIntroTestViewController() {
        let testVC = SpyrometerIntroTestViewController(withTopOffset: 24)
        testVC.onGetStarted = { [weak self] in
            self?.showTestViewController()
        }
        self.navigationController.pushViewController(testVC,
                                                     hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    /// Pushes the test view controller after a successful device connection.
    private func showTestViewController() {
        let testVC = SpyrometerTestViewController()
        testVC.onTestCompleted = { [weak self] results in
            self?.showResultsViewController(results: results)
        }
        testVC.onDeviceDisconnected = { [weak self] in
            self?.showDeviceDisconnectedViewController()
        }
        self.navigationController.pushViewController(testVC,
                                                     hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    /// Pushes the results view controller to display the spirometry test results.
    private func showResultsViewController(results: SOResults) {
        let resultsVC = SpyrometerResultsViewController(results: results)
        resultsVC.onRedoPressed = { [weak self] in
            self?.showIntroTestViewControllerFromRedo()
        }

        resultsVC.onDonePressed = { [weak self] results in
            guard let self = self else { return }
            self.sendResult(taskResult: results, presenter: resultsVC)
        }
        
        self.navigationController.pushViewController(resultsVC,
                                                     hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    /// Pushes the results view controller to display the spirometry test results.
    private func showDeviceDisconnectedViewController() {
        let resultsVC = SpiroDeviceDisconnectedViewController()
        resultsVC.onNextPressed = { [weak self] in
            if let introVC = self?.navigationController.viewControllers.first(where: { $0 is SpyrometerScanViewController }) {
                self?.navigationController.popToViewController(introVC,animated: true)
            }
        }
        
        self.navigationController.pushViewController(resultsVC,
                                                     hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func showIntroTestViewControllerFromRedo() {
        if let introVC = navigationController.viewControllers.first(where: { $0 is SpyrometerIntroTestViewController }) {
            navigationController.popToViewController(introVC, animated: true)
        } else {
            // If not found, push a new instance
            showIntroTestViewController()
        }
    }
    
    private func sendResult(taskResult: SOResults, presenter: UIViewController) {
        var taskResultWithUUID = taskResult.toDictionary() ?? [:]
        let resultUUID = UUID().uuidString
        taskResultWithUUID["ref_uuid"] = resultUUID
        repository.sendSpyroResults(results: taskResultWithUUID)
            .flatMap { [weak self] _ -> Single<Void> in
                guard let self = self else { return .error(NSError(domain: "InternalError", code: -1)) }
                return self.repository.sendTaskResult(taskId: self.taskIdentifier,
                                                      taskResult: TaskNetworkResult(data: taskResultWithUUID, attachedFile: nil))
            }
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
    private func makeScanViewController() -> SpyrometerScanViewController {
        let scanVC = SpyrometerScanViewController()
        scanVC.onScanCompleted = { [weak self] in
            self?.showIntroTestViewController()
        }
        scanVC.onCancelled = { [weak self] in
            self?.completionCallback()
        }
        return scanVC
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
