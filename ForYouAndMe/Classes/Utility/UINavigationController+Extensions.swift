//
//  UINavigationController+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/05/2020.
//

import UIKit

extension UINavigationController {
    
    func pushViewController(_ viewController: UIViewController,
                            animated: Bool,
                            completion: (() -> Void)?) {
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        pushViewController(viewController, animated: animated)
        CATransaction.commit()
    }
    
    /// Search the reversed array of navigation stack (from top to bottom) for an instance of the given sublass of `UIViewController`
    /// if a view controller is found, pop to it. Otherwise execute `assertionFailure`.
    /// - Parameter ofClass: the subclass of `UIViewController` to be searched
    /// - Parameter animated: Set this value to `true` to animate the transition. Pass `false` if you are setting up a navigation controller before its view is displayed.
    func popToExpectedViewController<T: UIViewController>(ofClass viewControllerClass: T.Type, animated: Bool) {
        guard let viewController = self.viewControllers.reversed().first(where: { $0 is T }) else {
            assertionFailure("Missing \(T.self) in navigation stack")
            return
        }
        self.popToViewController(viewController, animated: animated)
    }
}
