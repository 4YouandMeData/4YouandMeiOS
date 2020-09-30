//
//  SurveyQuestionProtocol.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 27/09/2020.
//

import Foundation

protocol SurveyQuestionProtocol: class {
    func answerDidChange(_ surveyQuestion: SurveyQuestion, answer: Any)
}
