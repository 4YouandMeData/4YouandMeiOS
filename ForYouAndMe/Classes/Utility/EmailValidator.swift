//
//  EmailValidator.swift
//  ForYouAndMe
//

import Foundation

enum EmailValidator {

    private static let pattern =
        "^[_A-Za-z0-9-+]+(\\.[_A-Za-z0-9-+]+)*@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*(\\.[A-Za-z]{2,})$"

    private static let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)

    static func isValid(_ email: String) -> Bool {
        return predicate.evaluate(with: email)
    }
}
