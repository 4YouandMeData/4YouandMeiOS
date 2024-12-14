//
//  UIViewController+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 08/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

extension UIViewController {
    func addCustomBackButton(withImage image: UIImage?) {
        assert(self.navigationController != nil, "Missing UINavigationController")
        if let image = image {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: image,
            style: .plain, target: self,
            action: #selector(self.customBackButtonPressed))
        }
    }
    
    func addCustomCloseButton(withImage image: UIImage?) {
        assert(self.navigationController != nil, "Missing UINavigationController")
        if let image = image {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: image,
            style: .plain, target: self,
            action: #selector(self.customCloseButtonPressed))
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
