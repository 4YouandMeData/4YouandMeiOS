//
//  UIViewController+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 08/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

extension UIViewController {
    func addCustomBackButton(withImage image: UIImage?, action: (() -> Void)? = nil) {
        assert(self.navigationController != nil, "Missing UINavigationController")
        if let image = image {
            let button = UIBarButtonItem(image: image, style: .plain) { [weak self] in
                if let action = action {
                    action()
                } else {
                    self?.navigationController?.popViewController(animated: true)
                }
            }
            self.navigationItem.leftBarButtonItem = button
        }
    }
    
    func addCustomCloseButton(withImage image: UIImage?, action: (() -> Void)? = nil) {
        assert(self.navigationController != nil, "Missing UINavigationController")
        if let image = image {
            let button = UIBarButtonItem(image: image, style: .plain) { [weak self] in
                if let action = action {
                    action()
                } else {
                    if let navigationController = self?.navigationController {
                        navigationController.dismiss(animated: true)
                    } else {
                        self?.dismiss(animated: true)
                    }
                }
            }
            self.navigationItem.leftBarButtonItem = button
        }
    }
    
    func addGenericCloseButton(withImage image: UIImage?, completion: (() -> Void)?) {
        assert(self.navigationController != nil, "Missing UINavigationController")
        if let image = image {
            let button = UIBarButtonItem(image: image, style: .plain) { [weak self] in
                if let navigationController = self?.navigationController {
                    navigationController.popViewController(animated: true)
                } else {
                    self?.dismiss(animated: true) {
                        completion?()
                    }
                }
            }
            self.navigationItem.leftBarButtonItem = button
        }
    }
    
    @objc func customBackButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func customCloseButtonPressed() {
        if let navigationController = self.navigationController {
            navigationController.dismiss(animated: true)
        } else {
            self.dismiss(animated: true)
        }
    }
    
    @objc func genericCloseButtonPressed(completion: (() -> Void)?) {
        if let navigationController = self.navigationController {
            navigationController.popViewController(animated: true)
        } else {
            self.dismiss(animated: true) {
                completion?()
            }
        }
    }
}
