//
//  NumericInputValidator.swift
//  ForYouAndMe
//

import Foundation

enum NumericInputValidator {

    static func shouldAcceptInteger(newText: String, maxDigits: Int) -> Bool {
        if newText.isEmpty { return true }
        guard newText.allSatisfy({ $0.isNumber }) else { return false }
        if newText.count > maxDigits { return false }
        if newText.count > 1 && newText.hasPrefix("0") { return false }
        return true
    }

    static func shouldAcceptDecimal(newText: String,
                                    maxIntegerDigits: Int,
                                    maxFractionDigits: Int) -> Bool {
        if newText.isEmpty { return true }
        let parts = newText.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return false }
        let intPart = String(parts[0])
        let fracPart = parts.count == 2 ? String(parts[1]) : ""
        guard !intPart.isEmpty else { return false }
        guard intPart.allSatisfy({ $0.isNumber }) else { return false }
        guard fracPart.allSatisfy({ $0.isNumber }) else { return false }
        if intPart.count > maxIntegerDigits { return false }
        if fracPart.count > maxFractionDigits { return false }
        if intPart.count > 1 && intPart.hasPrefix("0") { return false }
        return true
    }
}
