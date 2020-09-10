//
//  InformedConsentSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/06/2020.
//

import Foundation

struct InformedConsentSection {
    let id: String
    let type: String

    let minimumCorrectAnswers: Int
    let pages: [Page]
    let questions: [Question]
    let welcomePage: Page
    let successPage: Page?
    let failurePage: Page?
}

extension InformedConsentSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
pages.link_modal,\
welcome_page.link_1,\
success_page.link_2,\
success_page,\
failure_page.link_1,\
failure_page.link_2,\
questions.possible_answers
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case minimumCorrectAnswers = "minimum_required_correct_answers"
        case pages
        case questions
        case welcomePage = "welcome_page"
        case successPage = "success_page"
        case failurePage = "failure_page"
    }
}
