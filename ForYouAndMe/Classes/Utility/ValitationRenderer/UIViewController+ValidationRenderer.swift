//
//  UIViewController+ValidationRenderer.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import Validator

extension UIViewController: ValidationRenderer {
    
    public func renderValidationResult(_ validationResult: ValidationResult) {
        
        switch validationResult {
        case .valid: break
        case .invalid(let errors):
            var errorString = ""
            for validationError in errors {
                errorString += "\n" + validationError.message
            }
            let alert = UIAlertController(title: NSLocalizedString("VALIDATOR_GENERIC_ERROR",
                                                                   tableName: "ValidatorLocalizable",
                                                                   comment: ""),
                                          message: errorString, preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
