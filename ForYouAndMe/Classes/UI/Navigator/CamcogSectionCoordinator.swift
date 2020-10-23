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
    var activityPresenter: UIViewController? { return self.navigationController }
    let completionCallback: NotificationCallback
    let taskIdentifier: String
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
    // MARK: - PagedActivitySectionCoordinator
    weak var internalNavigationController: UINavigationController?
    let activity: Activity
    var coreViewController: UIViewController? { self.getCamCogViewController() }
    
    init(withTaskIdentifier taskIdentifier: String,
         activity: Activity,
         completionCallback: @escaping NotificationCallback) {
        self.taskIdentifier = taskIdentifier
        self.activity = activity
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init()
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
