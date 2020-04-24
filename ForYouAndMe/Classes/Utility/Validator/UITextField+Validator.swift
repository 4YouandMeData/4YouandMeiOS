//
//  UITextField+Validator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Validator

public extension UITextField {
    
    func addValidationRules(_ validationRules: [ValidationRuleType], fieldName: String? = nil) {
        
        var ruleSet = ValidationRuleSet<String>()
        for ruleType in validationRules {
            switch ruleType {
            case .minLength(let minLength):
                ruleSet.add(rule: Validator.getMinLengthRule(fieldName: fieldName ?? self.placeholder ?? "", minLength: minLength))
            case .maxLength(let maxLength):
                ruleSet.add(rule: Validator.getMaxLengthRule(fieldName: fieldName ?? self.placeholder ?? "", maxLength: maxLength))
            case .notEmpty:
                ruleSet.add(rule: Validator.getNotEmptyRule(fieldName: fieldName ?? self.placeholder ?? ""))
            case .email:
                ruleSet.add(rule: Validator.getEmailRule(fieldName: fieldName ?? self.placeholder ?? ""))
            case .fiscalCode:
                ruleSet.add(rule: Validator.getFiscalCodeRule(fieldName: fieldName ?? self.placeholder ?? ""))
            case .match(let inputText):
                ruleSet.add(rule: Validator.getMatchTextiInput(fieldName: fieldName ?? self.placeholder ?? "", textInput: inputText))
            }
        }
        var view = self
        view.validationRules = ruleSet
    }
}
