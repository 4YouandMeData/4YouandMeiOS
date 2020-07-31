//
//  UIViewController+Alert.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

extension UIViewController {
    public func showAlert(withTitle title: String,
                          message: String,
                          actions: [UIAlertAction],
                          tintColor: UIColor? = nil) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let tintColor = tintColor {
            alertView.view.tintColor = tintColor
        }
        actions.forEach { alertView.addAction($0) }
        present(alertView, animated: true, completion: nil)
    }
}
