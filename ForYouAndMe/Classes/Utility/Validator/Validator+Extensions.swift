//
//  Validator+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Validator

extension Bool: Validatable {}

public protocol ValidationRenderer {
    
    func renderValidationResult(_ validationResult: ValidationResult)
}

public protocol ValidationItem {
    
    associatedtype InputUI: ValidatableInterfaceElement
    
    var validationUI: InputUI { get }
    var validationRenderer: ValidationRenderer? { get }
}

public struct ValidationErrorImpl: ValidationError {
    
    public var message: String
    
    public init(withMessage message: String) {
        self.message = message
    }
}

public enum ValidationRuleType {
    case minLength(Int)
    case maxLength(Int)
    case notEmpty
    case email
    case fiscalCode
    case match(UITextInput)
}

public struct ValidationRuleMatch: ValidationRule {
    
    public typealias InputType = String
    
    public var error: ValidationError
    
    /**
     
     The text input element to that should be matched
     
     */
    public weak var match: UITextInput?
    
    /**
     
     Initializes a `ValidationRuleMatch` with an optionally supplied minimum
     character count, an optionally supplied maximum character count, and an
     error describing a failed validation.
     
     - Parameters:
     - match: A text input used to check the current text against
     - error: An error describing a failed validation.
     
     */
    public init(match: UITextInput, error: ValidationError) {
        self.match = match
        self.error = error
    }
    
    /**
     
     Validates the input.
     
     - Parameters:
     - input: Input to validate.
     
     - Returns:
     true if the input character count is between the minimum and maximum.
     
     */
    public func validate(input: String?) -> Bool {
        guard let input = input else { return false }
        
        if let textField = self.match as? UITextField {
            return input == textField.text
        } else if let textView = self.match as? UITextView {
            return input == textView.text
        }
        return false
    }
    
}

public struct ValidationRuleTrue: ValidationRule {
    
    public typealias InputType = Bool
    
    public var error: ValidationError
    
    /**
     
     Initializes a `ValidationRuleMatch` with an optionally supplied minimum
     character count, an optionally supplied maximum character count, and an
     error describing a failed validation.
     
     - Parameters:
     - match: A text input used to check the current text against
     - error: An error describing a failed validation.
     
     */
    public init(error: ValidationError) {
        self.error = error
    }
    
    /**
     
     Validates the input.
     
     - Parameters:
     - input: Input to validate.
     
     - Returns:
     true if the input character count is between the minimum and maximum.
     
     */
    public func validate(input: Bool?) -> Bool {
        return input ?? false
    }
}

public extension Validator {
    
    static private func localize(_ string: String) -> String {
        return NSLocalizedString(string, tableName: "ValidatorLocalizable", bundle: Bundle.main, comment: "")
    }
    
    static func getMinLengthRule(fieldName: String, minLength: Int) -> ValidationRuleLength {
        let message = "'\(fieldName)': \(localize("VALIDATOR_MINIMUM_PREFIX")) \(minLength) \(localize("VALIDATOR_CHARACTERS"))"
        return ValidationRuleLength(min: minLength, error: ValidationErrorImpl(withMessage: message))
    }
    
    static func getMaxLengthRule(fieldName: String, maxLength: Int) -> ValidationRuleLength {
        let message = "'\(fieldName)': \(localize("VALIDATOR_MAXIMUM_PREFIX")) \(maxLength) \(localize("VALIDATOR_CHARACTERS"))"
        return ValidationRuleLength(max: maxLength, error: ValidationErrorImpl(withMessage: message))
    }
    
    static func getNotEmptyRule(fieldName: String) -> ValidationRuleLength {
        let message = "'\(fieldName)': \(localize("VALIDATOR_IS_MANDATORY"))"
        return ValidationRuleLength(min: 1, error: ValidationErrorImpl(withMessage: message))
    }
    
    static func getEmailRule(fieldName: String) -> ValidationRulePattern {
        let message = "'\(fieldName)': \(localize("VALIDATOR_WRONG_FORMAT"))"
        return ValidationRulePattern(pattern: EmailValidationPattern.standard, error: ValidationErrorImpl(withMessage: message))
    }
    
    static func getFiscalCodeRule(fieldName: String) -> ValidationRulePattern {
        let pattern =
        """
 /^(?:(?:[B-DF-HJ-NP-TV-Z]|[AEIOU])[AEIOU][AEIOUX]|\
[B-DF-HJ-NP-TV-Z]{2}[A-Z]){2}[\\dLMNP-V]{2}(?:[A-EH\
LMPR-T](?:[04LQ][1-9MNP-V]|[1256LMRS][\\dLMNP-V])|[\
DHPS][37PT][0L]|[ACELMRT][37PT][01LM])(?:[A-MZ][1-9\
MNP-V][\\dLMNP-V]{2}|[A-M][0L](?:[1-9MNP-V][\\dLMNP\
-V]|[0L][1-9MNP-V]))[A-Z]$/i
"""
        let message = "'\(fieldName)': \(localize("VALIDATOR_WRONG_FORMAT"))"
        return ValidationRulePattern(pattern: pattern, error: ValidationErrorImpl(withMessage: message))
    }
    
    static func getMatchTextiInput(fieldName: String, textInput: UITextInput) -> ValidationRuleMatch {
        return ValidationRuleMatch(match: textInput,
                                   error: ValidationErrorImpl(withMessage: "'\(fieldName)': \(localize("VALIDATOR_MISMATCH"))"))
    }
    
    static func getMustBeChecked(errorMessage: String) -> ValidationRuleTrue {
        return ValidationRuleTrue(error: ValidationErrorImpl(withMessage: errorMessage))
    }
}

extension ValidationResult {
    public func merge(with result: ValidationResult) -> ValidationResult {

        switch self {

        case .valid: return result

        case .invalid(let errorMessages):

            switch result {

            case .valid:
                return self

            case .invalid(let errorMessagesAnother):
                return .invalid([errorMessages, errorMessagesAnother].flatMap { $0 })
            }
        }
    }
}

extension ValidationItem {
    @discardableResult func validate(showError: Bool = false) -> ValidationResult {
        // Trimming each textinput
        if let textInput = self.validationUI as? UITextInput,
            let textRange = textInput.textRange(from: textInput.beginningOfDocument, to: textInput.endOfDocument) {
            textInput.replace(textRange, withText: textInput.text(in: textRange)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        }
        
        let validationResult: ValidationResult = self.validationUI.validate()
        
        if showError {
            if let validationRenderer = self.validationRenderer {
                validationRenderer.renderValidationResult(validationResult)
            } else {
                print("No validation renderer available to show validation result: \(validationResult)")
            }
        }
        
        return validationResult
    }
}

extension Array where Element: ValidationItem {
    @discardableResult func validate(validationRenderer: ValidationRenderer?,
                                     showSingleResults: Bool) -> ValidationResult {
        
        let combinedValidationResult = self
            .map { return $0.validate(showError: showSingleResults)}
            .reduce(ValidationResult.valid, { $0.merge(with: $1) })
        
        if let validationRenderer = validationRenderer {
            validationRenderer.renderValidationResult(combinedValidationResult)
        } else {
            print("No validation renderer available to show combined validation Results: \(combinedValidationResult)")
        }
        
        return combinedValidationResult
    }
}
