//
//  SpyrometerSectionCoordinator.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 17/03/25.
//

import Foundation
import RxSwift

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
        
        self.spirometryService = MirSpirometryManager()

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
    private func showTestViewController() {
//        let testVC = SpyrometerTestViewController(service: spirometryService)
//        testVC.onTestFinished = { [weak self] resultsJSON in
//            self?.showResultsViewController(resultsJSON: resultsJSON)
//        }
//        testVC.onCancelled = { [weak self] in
//            self?.completionCallback()
//        }
//        self.navigationController.pushViewController(testVC,
//                                                     hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
//                                                     animated: true)
    }
    
    /// Pushes the results view controller to display the spirometry test results.
    private func showResultsViewController(resultsJSON: String) {
//        let resultsVC = SpyrometerResultsViewController(resultsJSON: resultsJSON)
//        resultsVC.onClose = { [weak self] in
//            self?.completionCallback()
//        }
//        self.navigationController.pushViewController(resultsVC,
//                                                     hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
//                                                     animated: true)
    }
    
    // MARK: - Building Child View Controllers
        
    /// Creates the scan view controller which manages device discovery and connection.
    /// When a device is successfully connected, the view controller triggers the onScanCompleted callback.
    private func makeScanViewController() -> SpyrometerScanViewController {
        let scanVC = SpyrometerScanViewController(service: spirometryService)
        scanVC.onScanCompleted = { [weak self] in
            self?.showTestViewController()
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
