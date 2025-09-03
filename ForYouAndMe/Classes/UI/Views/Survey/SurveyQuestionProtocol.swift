//
//  SurveyQuestionProtocol.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 27/09/2020.
//

import Foundation

protocol SurveyQuestionProtocol: AnyObject {
    func answerDidChange(_ surveyQuestion: SurveyQuestion, answer: Any)
    func surveyQuestion(_ question: SurveyQuestion, didUpdateValidity isValid: Bool)
}

extension SurveyQuestionProtocol {
    func surveyQuestion(_ question: SurveyQuestion, didUpdateValidity isValid: Bool) {}
}
