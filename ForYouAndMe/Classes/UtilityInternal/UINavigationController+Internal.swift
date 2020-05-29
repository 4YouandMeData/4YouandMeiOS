//
//  UINavigationController+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/05/2020.
//

import UIKit

extension UINavigationController {
    func clearLoadingViewController() {
        self.viewControllers.removeAll { (vc) -> Bool in
            return self.visibleViewController != vc && (vc is LoadingPage)
        }
    }
}
