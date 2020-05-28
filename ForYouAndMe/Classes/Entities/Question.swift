//
//  Question.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

struct Question {
    let id: String
    let type: String

    let text: String
    let possibleAnswers: [PossibleAnswer]
}

extension Question: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case text
        case possibleAnswers = "possible_answers"
    }
}
