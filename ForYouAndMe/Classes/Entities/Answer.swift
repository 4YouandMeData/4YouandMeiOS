//
//  Answer.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 09/07/2020.
//

import Foundation

struct Answer {
    let question: Question
    let possibleAnswer: PossibleAnswer
}

struct ProfilingAnswer {
    let question: ProfilingQuestion
    let profilingOption: ProfilingOption
}

extension Array where Element == Answer {
    func validate(withMinimumCorrectAnswers minimumCorrectAnswers: Int) -> Bool {
        var currentCorrectAnswerCount = 0
        self.forEach { currentCorrectAnswerCount += $0.possibleAnswer.correct ? 1 : 0 }
        return currentCorrectAnswerCount >= minimumCorrectAnswers
    }
}

extension Array where Element == ProfilingAnswer {
    func validate(withMinimumCorrectAnswers minimumCorrectAnswers: Int) -> Bool {
//        var currentCorrectAnswerCount = 0
//        self.forEach { currentCorrectAnswerCount += $0.possibleAnswer.correct ? 1 : 0 }
//        return currentCorrectAnswerCount >= minimumCorrectAnswers
        
        return false
    }
}
