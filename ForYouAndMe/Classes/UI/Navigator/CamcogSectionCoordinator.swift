//
//  CamcogSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 09/10/2020.
//

import Foundation
import RxSwift

class CamcogSectionCoordinator: NSObject, ActivitySectionCoordinator {
    
    var navigationController: UINavigationController = UINavigationController()
    
    // MARK: - ActivitySectionCoordinator
    var activityPresenter: UIViewController? { return self.navigationController }
    let completionCallback: NotificationCallback
    let taskIdentifier: String
    let navigator: AppNavigator
    let repository: Repository
    let disposeBag = DisposeBag()
    
    private let welcomePage: Page?
    private let successPage: Page?
    
    init(withTaskIdentifier taskIdentifier: String,
         completionCallback: @escaping NotificationCallback,
         welcomePage: Page?,
         successPage: Page?) {
        self.taskIdentifier = taskIdentifier
        self.welcomePage = welcomePage
        self.successPage = successPage
        self.completionCallback = completionCallback
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        super.init()
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController? {
        if let welcomeViewController = self.getWelcomeViewController() {
            return welcomeViewController
        } else {
            return self.getCamCogViewController()
        }
    }
    
    private func getWelcomeViewController() -> UIViewController? {
        guard let welcomePage = self.welcomePage else {
            return nil
        }
        let data = InfoPageData(page: welcomePage,
                                addAbortOnboardingButton: false,
                                addCloseButton: true,
                                allowBackwardNavigation: false,
                                bodyTextAlignment: .left,
                                bottomViewStyle: .horizontal,
                                customImageHeight: nil)
        
        let welcomeViewController = InfoPageViewController(withPageData: data,
                                                          coordinator: self)
        
        self.navigationController.viewControllers = [welcomeViewController]
        return navigationController
    }
    
    private func getCamCogViewController() -> UIViewController {
        
        let url = URL(string: "\(Constants.Network.BaseUrl)/camcog/tasks/\(self.taskIdentifier)")!
        return ReactiveAuthWebViewController(withTitle: "",
                                             url: url,
                                             allowBackwardNavigation: false,
                                             onSuccessCallback: { [weak self] _ in
                                                self?.showSuccessViewController()
                                             }, onFailureCallback: { [weak self] _ in
                                                self?.completionCallback()
                                             })
    }
    
    private func showSuccessViewController() {
        if let successPage = self.successPage {
            let data = InfoPageData.createResultPageData(withPage: successPage)
            let successViewController = InfoPageViewController(withPageData: data,
                                                              coordinator: self)
            self.navigationController.pushViewController(successViewController, animated: true)
        } else {
            self.completionCallback()
        }
    }
}

extension CamcogSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] {
        if let welcomePage = self.welcomePage {
            return [welcomePage]
        } else {
            return []
        }
    }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.successPage?.id == page.id {
            self.completionCallback()
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        let camcogViewController = self.getCamCogViewController()
        self.navigationController.pushViewController(camcogViewController, animated: true)
    }
    
    func onUnhandledSecondaryButtonNavigation(page: Page) {
        self.delayActivity()
    }
}
