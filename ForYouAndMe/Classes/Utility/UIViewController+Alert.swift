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
                          cancelText: String,
                          confirmText: String,
                          tintColor: UIColor? = nil,
                          cancel: @escaping (() -> Void) = {},
                          confirm: @escaping (() -> Void) = {}) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: cancelText, style: .cancel) { _ in
            cancel()
        }
        let confirmAction = UIAlertAction(title: confirmText, style: .default) { _ in
            confirm()
        }
        if let tintColor = tintColor {
            alertView.view.tintColor = tintColor
        }
        alertView.addAction(cancelAction)
        alertView.addAction(confirmAction)
        present(alertView, animated: true, completion: nil)
    }
    
    public func showAlert(withTitle title: String,
                          message: String,
                          tintColor: UIColor? = nil,
                          completion: @escaping (() -> Void)) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: "OK", style: .cancel) { _ in
            completion()
        }
        if let tintColor = tintColor {
            alertView.view.tintColor = tintColor
        }
        alertView.addAction(closeAction)
        present(alertView, animated: true, completion: nil)
    }
}
