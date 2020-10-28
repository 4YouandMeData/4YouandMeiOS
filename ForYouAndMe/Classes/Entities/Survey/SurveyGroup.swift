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
    
    let pages: [Page]
    let welcomePage: Page
    let successPage: Page?
    
    let rescheduleTimes: Int?
}

extension SurveyGroup: JSONAPIMappable {
    static var includeList: String? = """
survey_blocks.pages,\
survey_blocks.intro_page,\
survey_blocks.success_page,\
survey_blocks.questions.possible_answers,\
pages.link_1,\
welcome_page.link_1,\
success_page
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case surveys = "survey_blocks"
        case pages
        case welcomePage = "welcome_page"
        case successPage = "success_page"
        case rescheduleTimes = "reschedule_times"
    }
}
