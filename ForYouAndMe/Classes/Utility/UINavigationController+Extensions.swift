//
//  UINavigationController+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/05/2020.
//

import UIKit

extension UINavigationController {
    
    func pushViewController(_ viewController: UIViewController,
                            hidesBottomBarWhenPushed: Bool,
                            animated: Bool) {
        viewController.hidesBottomBarWhenPushed = hidesBottomBarWhenPushed
        self.pushViewController(viewController, animated: animated)
    }
    
    func pushViewController(_ viewController: UIViewController,
                            hidesBottomBarWhenPushed: Bool,
                            animated: Bool,
                            completion: (() -> Void)?) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        self.pushViewController(viewController, animated: animated)
        CATransaction.commit()
    }
    
    /// Search the reversed array of navigation stack (from top to bottom) for an instance of the given sublass of `UIViewController`
    /// if a view controller is found, pop to it. Otherwise execute `assertionFailure`.
    /// - Parameter viewControllerClass: the subclass of `UIViewController` to be searched
    /// - Parameter animated: Set this value to `true` to animate the transition.
    /// Pass `false` if you are setting up a navigation controller before its view is displayed.
    func popToExpectedViewController<T: UIViewController>(ofClass viewControllerClass: T.Type, animated: Bool) {
        guard let viewController = self.viewControllers.reversed().first(where: { $0 is T }) else {
            assertionFailure("Missing \(T.self) in navigation stack")
            return
        }
        self.popToViewController(viewController, animated: animated)
    }
    
    func preventPopWithSwipe() {
        if self.responds(to: #selector(getter: UINavigationController.interactivePopGestureRecognizer)) {
            self.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}
