//
//  SurveyQuestion.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation
import RxSwift

enum SurveyQuestionType: String {
    case numerical = "SurveyQuestionNumerical"
    case pickOne = "SurveyQuestionPickOne"
    case pickMany = "SurveyQuestionPickMany"
    case textInput = "SurveyQuestionText"
    case dateInput = "SurveyQuestionDate"
    case scale = "SurveyQuestionScale"
    case range = "SurveyQuestionRange"
    case clickable = "SurveyQuestionClickableImage"
}

struct SurveyQuestion {
    let id: String
    let type: String
    
    @EnumStringDecodable
    var questionType: SurveyQuestionType
    
    let body: String
    @ImageDecodable
    var image: UIImage?
    
    @ImageDecodable
    var clickableImage: UIImage?
    
    // Details
    var minimum: Int?
    var maximum: Int?
    @StringToInt
    var interval: Int?
    @NilIfEmptyString
    var minimumDisplay: String?
    @NilIfEmptyString
    var maximumDisplay: String?
    @NilIfEmptyString
    var minimumLabel: String?
    @NilIfEmptyString
    var maximumLabel: String?
    @NilIfEmptyString
    var placeholder: String?
    var maxCharacters: Int?
    @FailableDateValue<DateStrategy>
    var minimumDate: Date?
    @FailableDateValue<DateStrategy>
    var maximumDate: Date?
    
    @FailableDecodable
    var options: [SurveyQuestionOption]?
    
    @FailableArrayExcludeInvalid
    var targets: [SurveyTarget]?
    
    let skippable: Bool
}

extension SurveyQuestion: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case questionType = "question_type"
        case body = "text"
        case image
        case clickableImage = "clickable_image"
        case minimum = "min"
        case maximum = "max"
        case interval = "interval"
        case minimumDisplay = "min_display"
        case maximumDisplay = "max_display"
        case minimumLabel = "min_label"
        case maximumLabel = "max_label"
        case placeholder = "placeholder"
        case maxCharacters = "max_characters"
        case minimumDate = "min_date"
        case maximumDate = "max_date"
        case options = "possible_answers"
        case skippable
        case targets
    }
}

extension SurveyQuestion: Hashable, Equatable {
    static func == (lhs: SurveyQuestion, rhs: SurveyQuestion) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
