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
}
