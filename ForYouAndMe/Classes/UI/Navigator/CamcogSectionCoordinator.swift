//
//  CamcogSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 09/10/2020.
//

import Foundation
import RxSwift

class CamcogSectionCoordinator: NSObject, PagedActivitySectionCoordinator {
    
    // MARK: - ActivitySectionCoordinator
    let completionCallback: NotificationCallback
    let taskIdentifier: String
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
    // MARK: - PagedActivitySectionCoordinator
    weak var activitySectionViewController: ActivitySectionViewController?
    let pagedSectionData: PagedSectionData
    var currentlyRescheduledTimes: Int
    var maxRescheduleTimes: Int
    var coreViewController: UIViewController? { self.getCamCogViewController() }
    
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
        super.init()
    }
    
    deinit {
        print("CamcogSectionCoordinator - deinit")
    }
    
    // MARK: - Public Methods
    
    private func getCamCogViewController() -> UIViewController {
        
        let url = URL(string: "\(Constants.Network.BaseUrl)/camcog/tasks/\(self.taskIdentifier)")!
        return ReactiveAuthWebViewController(withTitle: "",
                                             url: url,
                                             allowBackwardNavigation: false,
                                             onSuccessCallback: { [weak self] _ in
                                                self?.showSuccessPage()
                                             }, onFailureCallback: { [weak self] _ in
                                                self?.completionCallback()
                                             })
    }
}
