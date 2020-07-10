//
//  Answer.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 09/07/2020.
//

import Foundation

struct Answer {
    let question: Question
    var currentAnswer: PossibleAnswer?
}

extension Array where Element == Answer {
    func validate(withMinimumCorrectAnswers minimumCorrectAnswers: Int) -> Bool {
        var currentCorrectAnswerCount = 0
        self.forEach { currentCorrectAnswerCount += $0.currentAnswer?.correct ?? false ? 1 : 0 }
        return currentCorrectAnswerCount >= minimumCorrectAnswers
    }
}
