//
//  SurveyGroup.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation

struct SurveyGroup {
    let id: String
    let type: String
    
    let surveys: [SurveyTask]
}

extension SurveyGroup: JSONAPIMappable {
    static var includeList: String? = """
survey_blocks.pages,\
survey_blocks.intro_page,\
survey_blocks.success_page,\
survey_blocks.questions.possible_answers
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case surveys = "survey_blocks"
    }
}
