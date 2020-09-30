//
//  SurveyQuestionPickerFactory.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 27/09/2020.
//

struct SurveyQuestionPickerFactory {
  
    static func getSurveyQuestionPicker(for question: SurveyQuestion) -> UIView {
        switch question.questionType {
        case .numerical:
            return SurveyQuestionNumerical(surveyQuestion: question)
        case .pickOne:
            return SurveyQuestionPickOne(surveyQuestion: question)
        case .pickMany:
            return SurveyQuestionPickMany(surveyQuestion: question)
        case .textInput:
            return SurveyQuestionTextInput(surveyQuestion: question)
        case .dateInput:
            return SurveyQuestionDate(surveyQuestion: question)
        case .scale:
            return SurveyQuestionScale(surveyQuestion: question)
        case .range:
            return SurveyRangePicker(surveyQuestion: question)
        }
    }
}
