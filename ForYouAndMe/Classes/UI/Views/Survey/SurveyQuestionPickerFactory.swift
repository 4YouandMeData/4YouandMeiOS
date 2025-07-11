//
//  SurveyQuestionPickerFactory.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 27/09/2020.
//

struct SurveyQuestionPickerFactory {
  
    static func getSurveyQuestionPicker(for question: SurveyQuestion,
                                        delegate: SurveyQuestionProtocol) -> UIView {
        switch question.questionType {
        case .numerical:
            return SurveyQuestionNumerical(surveyQuestion: question, delegate: delegate)
        case .pickOne:
            return SurveyQuestionPickOne(surveyQuestion: question, delegate: delegate)
        case .pickOneImage:
            return SurveyQuestionPickOneWithImage(surveyQuestion: question, delegate: delegate)
        case .pickMany:
            return SurveyQuestionPickMany(surveyQuestion: question, delegate: delegate)
        case .textInput:
            return SurveyQuestionTextInput(surveyQuestion: question, delegate: delegate)
        case .dateInput:
            return SurveyQuestionDate(surveyQuestion: question, delegate: delegate)
        case .scale:
            return SurveyQuestionScale(surveyQuestion: question, delegate: delegate)
        case .range:
            return SurveyRangePicker(surveyQuestion: question, delegate: delegate)
        case .clickable:
            return SurveyClickableImage(surveyQuestion: question, delegate: delegate)
        }
    }
}
