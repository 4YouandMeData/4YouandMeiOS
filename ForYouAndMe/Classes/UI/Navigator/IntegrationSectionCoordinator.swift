//
//  IntegrationSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation
import RxSwift
#if TERRA
import TerraiOS
#endif

enum IntegrationSpecialLinkBehaviour: CaseIterable {
    static var allCases: [IntegrationSpecialLinkBehaviour] {
        return [.download(app: nil), .open(app: nil), .active(app: nil)]
    }
    
    case download(app: Integration?)
    case open(app: Integration?)
    case active(app: Integration?)
    
    var keyword: String {
        switch self {
        case .download: return "download"
        case .open: return "open"
        case .active: return "active"
        }
    }
    
    var caseType: CaseType {
        switch self {
        case .download: return .download
        case .open: return .open
        case .active: return .active
        }
    }
    
    enum CaseType {
        case download
        case open
        case active
    }
}

class IntegrationSectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
#if TERRA
    var terra: TerraManager?
#endif
    
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = true
    
    public unowned var navigationController: UINavigationController
    
    private let navigator: AppNavigator
    
    private let sectionData: IntegrationSection
    private let completionCallback: NavigationControllerCallback
    private let disposeBag = DisposeBag()

    init(withSectionData sectionData: IntegrationSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.navigator = Services.shared.navigator
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
}

extension IntegrationSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    /// FUAM-4036. The section starts at the welcome page, else at the success
    /// page (whose primary button completes the step, see
    /// `performCustomPrimaryButtonNavigation`). The loose `pages` are reachable
    /// exclusively via page links, never as an automatic first step or a
    /// fallback. A section with neither page is skipped before the coordinator
    /// is ever built (see `OnboardingSection.getAsyncCoordinatorRequest`).
    func getStartingPage() -> UIViewController {
        guard let startingPage = self.sectionData.startingPage else {
            assertionFailure("Integration section without welcome and success pages should have been skipped")
            return UIViewController()
        }
        return IntegrationPageViewController(withPage: startingPage, coordinator: self, backwardNavigation: false)
    }
    
    func showPage(_ page: Page) {
        let viewController = IntegrationPageViewController(withPage: page, coordinator: self, backwardNavigation: true)
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    /// FUAM-4036. Replaces the default `PagedSectionCoordinator` lookup, which
    /// only searches `pages` and dead-ends on an unknown id. A link to the
    /// success page id goes to the success page (shown once, its primary button
    /// completes the step); a link to an id missing from the payload ends the
    /// chain like a page without links does.
    func showLinkedPage(forPageRef pageRef: PageRef) {
        let previousController = self.navigationController.viewControllers.reversed().first { viewController -> Bool in
            return (viewController as? PageProvider)?.page.id == pageRef.id
        }
        if let previousController = previousController {
            self.navigationController.popToViewController(previousController, animated: true)
        } else if let nextPage = self.sectionData.linkedPage(forPageRef: pageRef) {
            self.showPage(nextPage)
        } else {
            self.showSuccessPageOrComplete()
        }
    }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController)
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        self.showSuccessPageOrComplete()
    }
    
    /// End of the link chain: the success page if there is one, otherwise the step is complete.
    private func showSuccessPageOrComplete() {
        if let successPage = self.sectionData.successPage {
            self.showPage(successPage)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension IntegrationSectionCoordinator: IntegrationPageCoordinator {
    func onIntegrationPageExternalLinkButtonPressed(page: Page) {
        guard let externalLinkUrl = page.externalLinkUrl else {
            assertionFailure("Missing expected external link url")
            return
        }
        let viewController = ReactiveAuthWebViewController(withTitle: "",
                                                           url: externalLinkUrl,
                                                           allowBackwardNavigation: true,
                                                           onSuccessCallback: { loginViewController in
                                                            loginViewController.dismiss(animated: true, completion: { [weak self] in
                                                                
                                                                self?.onPagePrimaryButtonPressed(page: page)
                                                            })
                                                           },
                                                           onFailureCallback: { loginViewController in
                                                            loginViewController.dismiss(animated: true, completion: nil)
                                                           })
        let navigationViewController = UINavigationController(rootViewController: viewController)
        navigationViewController.preventPopWithSwipe()
        self.navigationController.present(navigationViewController, animated: true, completion: nil)
    }
    
    func onIntegrationPageSpecialLinkButtonPressed(page: Page) {
        guard let specialLinkBehaviour = page.integrationSpecialLinkBehaviour else {
            assertionFailure("Missing expected special link behaviour")
            return
        }
        
        switch specialLinkBehaviour {
        case .download(let app):
            guard let app = app else {
                assertionFailure("Missing app for download behaviour")
                return
            }
            self.navigator.openExternalUrl(app.storeUrl)
        case .open(let app):
            guard let app = app else {
                assertionFailure("Missing app for open behaviour")
                return
            }
            self.navigator.openIntegrationApp(forIntegration: app)
        case .active(let app):
            guard app != nil else {
                assertionFailure("Missing app for open behaviour")
                return
            }
            #if TERRA
            Services.shared.terraService
                .initialize()
                .flatMap {
                    Services.shared.terraService.connectToTerraIfAvailable()
                }
                .observe(on: MainScheduler.instance)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    self?.onPagePrimaryButtonPressed(page: page)
                }, onFailure: { _ in })
                .disposed(by: disposeBag)
            #endif
        }
    }
}
