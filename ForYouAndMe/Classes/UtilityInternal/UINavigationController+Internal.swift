//
//  UINavigationController+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/05/2020.
//

import UIKit
import RxSwift

extension UINavigationController {
    func clearLoadingViewController() {
        self.viewControllers.removeAll { (vc) -> Bool in
            return self.visibleViewController != vc && (vc is LoadingPage)
        }
    }
    
    func loadViewForRequest<T>(_ requestSingle: Single<T>, viewForData: @escaping ((T) -> UIViewController)) {
        self.loadViewForRequest(requestSingle, hidesBottomBarWhenPushed: false, viewForData: viewForData)
    }
    
    func loadViewForRequest<T>(_ requestSingle: Single<T>,
                               hidesBottomBarWhenPushed: Bool,
                               viewForData: @escaping ((T) -> UIViewController)) {
        let loadingInfo = LoadingInfo(requestSingle: requestSingle,
                                      completionCallback: { [weak self] loadedData in
                                        guard let self = self else { return }
                                        let viewController = viewForData(loadedData)
                                        self.pushViewController(viewController,
                                                                animated: false,
                                                                completion: { [weak self] in
                                                                    guard let self = self else { return }
                                                                    self.clearLoadingViewController()
                                        })
        })
        let loadingViewController = LoadingViewController(loadingMode: .genericLoad(loadingInfo: loadingInfo))
        loadingViewController.hidesBottomBarWhenPushed = hidesBottomBarWhenPushed
        self.pushViewController(loadingViewController, animated: true)
    }
    
    override open var shouldAutorotate: Bool {
        if let visibleVC = visibleViewController, ((visibleVC as? IntroVideoViewController) != nil) {
            return visibleVC.shouldAutorotate
        }
        return false
    }
}
