//
//  UINavigationController+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/05/2020.
//

import UIKit
import RxSwift
import ResearchKit

extension UINavigationController {
    func clearLoadingViewController() {
        self.viewControllers.removeAll { (vc) -> Bool in
            return self.visibleViewController != vc && (vc is LoadingPage)
        }
    }
    
    func loadViewForRequest<T>(_ requestSingle: Single<T>, viewForData: @escaping ((T) -> UIViewController?)) {
        self.loadViewForRequest(requestSingle, hidesBottomBarWhenPushed: false, allowBackwardNavigation: false, viewForData: viewForData)
    }

    /// FUAM-4045. `viewForData` may return nil, meaning "there is nothing to
    /// show for this data": the loading page is popped and `onNoView` is
    /// invoked instead of pushing anything (used to skip an empty onboarding
    /// section).
    func loadViewForRequest<T>(_ requestSingle: Single<T>,
                               hidesBottomBarWhenPushed: Bool,
                               allowBackwardNavigation: Bool,
                               viewForData: @escaping ((T) -> UIViewController?),
                               onNoView: (() -> Void)? = nil) {
        let loadingInfo = LoadingInfo(requestSingle: requestSingle,
                                      completionCallback: { [weak self] loadedData in
                                        guard let self = self else { return }
                                        guard let viewController = viewForData(loadedData) else {
                                            // Drop the loading page before handing over, so the
                                            // skipped step leaves no trace in the back stack.
                                            if self.viewControllers.count > 1, self.visibleViewController is LoadingPage {
                                                self.popViewController(animated: false)
                                            }
                                            onNoView?()
                                            return
                                        }
                                        self.pushViewController(viewController,
                                                                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                                                animated: false,
                                                                completion: { [weak self] in
                                                                    guard let self = self else { return }
                                                                    self.clearLoadingViewController()
                                                                })
                                      })
        let loadingViewController = LoadingViewController(loadingMode: .genericLoad(loadingInfo: loadingInfo,
                                                                                    allowBack: allowBackwardNavigation))
        self.pushViewController(loadingViewController,
                                hidesBottomBarWhenPushed: hidesBottomBarWhenPushed,
                                animated: true)
    }
}
