//
//  PossibleAnswer.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

struct PossibleAnswer {
    let id: String
    let type: String

    let text: String
    let correct: Bool
}

extension PossibleAnswer: JSONAPIMappable {}

extension PossibleAnswer: Equatable {
    static func == (lhs: PossibleAnswer, rhs: PossibleAnswer) -> Bool {
        return lhs.id == rhs.id
    }
}

extension PossibleAnswer {
    var isOther: Bool {
        guard StringsProvider.string(forKey: .questionOtherEnabled).lowercased() == "true" else { return false }
        let otherKeyword = StringsProvider.string(forKey: .questionOtherText).lowercased()
        return self.text.lowercased().contains(otherKeyword)
    }
}
