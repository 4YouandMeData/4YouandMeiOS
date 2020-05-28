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

    let questions: [Question]
    let welcomePage: Page
    let successPage: Page
    let failurePage: Page
}

extension ScreeningSection: JSONAPIMappable {
    static var includeList: String? = "welcome_page,success_page,failure_page,screening_questions.possible_answers"
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case questions = "screening_questions"
        case welcomePage = "welcome_page"
        case successPage = "success_page"
        case failurePage = "failure_page"
    }
}
