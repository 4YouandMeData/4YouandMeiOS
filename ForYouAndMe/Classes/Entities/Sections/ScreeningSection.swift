//
//  ScreeningSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

struct ScreeningSection {
    let id: String
    let type: String

    let pages: [Page]
    let questions: [Question]
    let welcomePage: Page
    let successPage: Page?
    let failurePage: Page?
}

extension ScreeningSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
welcome_page.link_1,\
welcome_page.link_2,\
success_page,\
failure_page,\
screening_questions.possible_answers
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pages
        case questions = "screening_questions"
        case welcomePage = "welcome_page"
        case successPage = "success_page"
        case failurePage = "failure_page"
    }
}
