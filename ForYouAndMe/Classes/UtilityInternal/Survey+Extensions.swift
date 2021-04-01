//
//  Survey+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/10/2020.
//

import Foundation

extension SurveyResult {
    var isValid: Bool {
        switch self.question.questionType {
        case .numerical:
            guard let stringValue = self.answer as? String else { return false }
            if stringValue == Constants.Survey.NumericTypeMinValue {
                return true
            } else if stringValue == Constants.Survey.NumericTypeMaxValue {
                return true
            } else if let intValue = Int(stringValue) {
                if let minimum = self.question.minimum, intValue < minimum {
                    return false
                }
                if let maximum = self.question.maximum, intValue > maximum {
                    return false
                }
                return true
            }
            return false
        case .pickOne:
            guard let options = self.question.options else { return false }
            guard let optionIdentifier = self.answer as? SurveyPickResponse else { return false }
            return options.contains(where: { $0.id == optionIdentifier.answerId })
        case .pickMany:
            guard let options = self.question.options else { return false }
            guard let optionIdentifiers = self.answer as? [SurveyPickResponse] else { return false }
            return optionIdentifiers.map({$0.answerId}).allSatisfy(options.map { $0.id }.contains)
        case .textInput:
            guard let text = self.answer as? String else { return false }
            if let maxCharacters = self.question.maxCharacters, text.count > maxCharacters { return false }
            return !text.isEmpty
        case .dateInput:
            guard let dateStr = self.answer as? String else { return false }
            guard let date = DateStrategy.dateFormatter.date(from: dateStr) else { return false }
            if let minimumDate = self.question.minimumDate, date < minimumDate { return false }
            if let maximumDate = self.question.maximumDate, date > maximumDate { return false }
            return true
        case .scale:
            guard let value = self.answer as? Int else { return false }
            if let minimum = self.question.minimum, value < minimum { return false }
            if let maximum = self.question.maximum, value > maximum { return false }
            return true
        case .range:
            guard let value = self.answer as? Int else { return false }
            if let minimum = self.question.minimum, value < minimum { return false }
            if let maximum = self.question.maximum, value > maximum { return false }
            return true
        }
    }
    
    var numericValue: Int? {
        switch self.question.questionType {
        case .numerical:
            guard let stringValue = self.answer as? String else { return nil }
            return Int(stringValue)
        case .pickOne: return nil
        case .pickMany: return nil
        case .textInput: return nil
        case .dateInput: return nil
        case .scale: return self.answer as? Int
        case .range: return self.answer as? Int
        }
    }
    
    var optionsIdentifiers: [String]? {
        switch self.question.questionType {
        case .numerical: return nil
        case .pickOne:
            guard let optionIdentifier = self.answer as? SurveyPickResponse else { return nil }
            let optionId = optionIdentifier.answerId
            return [optionId]
        case .pickMany:
            guard let answers = self.answer as? [SurveyPickResponse] else { return nil }
            let answersIds = answers.map({$0.answerId})
            return answersIds
        case .textInput: return nil
        case .dateInput: return nil
        case .scale: return nil
        case .range: return nil
        }
    }
}

extension SurveyQuestion {
    var isValid: Bool {
        switch self.questionType {
        case .numerical:
            guard let minimum = self.minimum,
                  let maximum = self.maximum,
                  minimum < maximum else {
                return false
            }
        case .pickOne:
            guard let options = self.options, options.count > 0 else { return false }
        case .pickMany:
            guard let options = self.options, options.count > 0 else { return false }
        case .textInput:
            guard let maxCharacters = self.maxCharacters, maxCharacters > 0 else { return false }
        case .dateInput:
            guard let minimumDate = self.minimumDate,
                  let maximumDate = self.maximumDate,
                  minimumDate < maximumDate else {
                return false
            }
        case .scale:
            guard let minimum = self.minimum,
                  let maximum = self.maximum,
                  minimum < maximum else {
                return false
            }
            let interval = self.interval ?? Constants.Survey.ScaleTypeDefaultInterval
            guard interval > 0, minimum + interval <= maximum else {
                return false
            }
        case .range:
            guard let minimum = self.minimum,
                  let maximum = self.maximum,
                  minimum < maximum else {
                return false
            }
        }
        return true
    }
}

extension SurveyTask {
    var isValid: Bool {
        return self.validQuestions.count > 0
    }
    
    var validQuestions: [SurveyQuestion] {
        return self.questions.filter { $0.isValid }
    }
}

extension SurveyGroup {
    var validSurveys: [SurveyTask] {
        return self.surveys.filter { $0.isValid }
    }
}

extension Array where Element == SurveyTarget {
    func getTargetMatchingCriteria(forNumber number: Int) -> SurveyTarget? {
        self.first { target in
            guard let criteria = target.criteria else {
                assertionFailure("Missing expected criteria")
                return true
            }
            switch criteria {
            case .range:
                if let minimum = target.minimum, number < minimum { return false }
                if let maximum = target.maximum, number > maximum { return false }
                return true
            }
        }
    }
    
    func getTargetMatchingCriteria(forOptionsIdentifiers optionsIdentifiers: [String]) -> SurveyTarget? {
        return self.first(where: { target in
            if let answerId = target.answerId {
                return optionsIdentifiers.contains(answerId)
            } else {
                return false
            }
        })
    }
}
