//
//  VideoDiarySectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 26/08/2020.
//

import Foundation
import RxSwift

class VideoDiarySectionCoordinator: NSObject, PagedActivitySectionCoordinator {
    
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
    var coreViewController: UIViewController? { VideoDiaryRecorderViewController(taskIdentifier: self.taskIdentifier,
                                                                                 coordinator: self) }
    
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
        super.init()
        
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.videoDiary.rawValue,
                                                  screenClass: String(describing: type(of: self))))
    }
    
    deinit {
        print("VideoDiarySectionCoordinator - deinit")
        self.deleteVideoResult()
    }
    
    // MARK: - Public Methods
    
    public func onRecordCompleted() {
        self.deleteVideoResult()
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.videoDiaryComplete.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.showSuccessPage()
    }
    
    public func onSuccessCompleted() {
        self.completionCallback()
    }
    
    public func onCancelTask() {
        self.completionCallback()
    }
    
    // MARK: - Private Methods
    
    private func deleteVideoResult() {
       try? FileManager.default.removeItem(atPath: Constants.Task.VideoResultURL.path)
    }
}
