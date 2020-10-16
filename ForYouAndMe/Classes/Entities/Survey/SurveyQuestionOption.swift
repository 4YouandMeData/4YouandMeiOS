//
//  SurveyQuestionOption.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation

struct SurveyQuestionOption {
    let id: String
    let type: String
    
    let value: String
}

extension SurveyQuestionOption: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value = "text"
    }
}
