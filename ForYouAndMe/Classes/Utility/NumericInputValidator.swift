//
//  NumericInputValidator.swift
//  ForYouAndMe
//

import Foundation

enum NumericInputValidator {

    /// Any character the user could legitimately type as a decimal separator.
    /// iOS' decimalPad shows the locale's separator (e.g. "," in it_IT,
    /// "." in en_US), so we accept both rather than locking to one.
    private static let decimalSeparators: Set<Character> = [".", ","]

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
        let separatorCount = newText.filter { decimalSeparators.contains($0) }.count
        guard separatorCount <= 1 else { return false }
        let firstSeparatorIndex = newText.firstIndex(where: { decimalSeparators.contains($0) })
        let intPart: String
        let fracPart: String
        if let idx = firstSeparatorIndex {
            intPart = String(newText[..<idx])
            fracPart = String(newText[newText.index(after: idx)...])
        } else {
            intPart = newText
            fracPart = ""
        }
        guard !intPart.isEmpty else { return false }
        guard intPart.allSatisfy({ $0.isNumber }) else { return false }
        guard fracPart.allSatisfy({ $0.isNumber }) else { return false }
        if intPart.count > maxIntegerDigits { return false }
        if fracPart.count > maxFractionDigits { return false }
        if intPart.count > 1 && intPart.hasPrefix("0") { return false }
        return true
    }

    /// Normalize any accepted decimal separator to "." so the result can
    /// be parsed with Double() regardless of locale.
    static func normalizedDecimalString(_ text: String) -> String {
        return text.replacingOccurrences(of: ",", with: ".")
    }
}
