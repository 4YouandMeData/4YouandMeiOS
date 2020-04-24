//
//  UITextView+Validator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Validator

public extension UITextView {
    
    func addValidationRules(_ validationRules: [ValidationRuleType], fieldName: String?) {
        
        var ruleSet = ValidationRuleSet<String>()
        for ruleType in validationRules {
            switch ruleType {
            case .minLength(let minLength):
                ruleSet.add(rule: Validator.getMinLengthRule(fieldName: fieldName ?? "", minLength: minLength))
            case .maxLength(let maxLength):
                ruleSet.add(rule: Validator.getMaxLengthRule(fieldName: fieldName ?? "", maxLength: maxLength))
            case .notEmpty:
                ruleSet.add(rule: Validator.getNotEmptyRule(fieldName: fieldName ?? ""))
            case .email:
                ruleSet.add(rule: Validator.getEmailRule(fieldName: fieldName ?? ""))
            case .fiscalCode:
                ruleSet.add(rule: Validator.getFiscalCodeRule(fieldName: fieldName ?? ""))
            case .match(let inputText):
                ruleSet.add(rule: Validator.getMatchTextiInput(fieldName: fieldName ?? "", textInput: inputText))
            }
        }
        var view = self
        view.validationRules = ruleSet
    }
}
