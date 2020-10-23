//
//  VideoDiarySectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 26/08/2020.
//

import Foundation
import RxSwift

class VideoDiarySectionCoordinator: NSObject, PagedActivitySectionCoordinator {
    
    // MARK: - ActivitySectionCoordinator
    var activityPresenter: UIViewController? { return self.navigationController }
    let taskIdentifier: String
    let completionCallback: NotificationCallback
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
    // MARK: - PagedActivitySectionCoordinator
    weak var internalNavigationController: UINavigationController?
    let activity: Activity
    var coreViewController: UIViewController? { VideoDiaryRecorderViewController(taskIdentifier: self.taskIdentifier,
                                                                                coordinator: self) }
    
    private let analytics: AnalyticsService
    
    init(withTaskIdentifier taskIdentifier: String,
         activity: Activity,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = taskIdentifier
        self.activity = activity
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        super.init()
        
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.videoDiary.rawValue,
                                                  screenClass: String(describing: type(of: self))))
    }
    
    deinit {
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
       try? FileManager.default.removeItem(atPath: Constants.Task.videoResultURL.path)
    }
}
