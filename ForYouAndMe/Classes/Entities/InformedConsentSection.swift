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

    let questions: [Question]
    let welcomePage: InfoPage
    let successPage: InfoPage
    let failurePage: InfoPage
}

extension InformedConsentSection: JSONAPIMappable {
    static var includeList: String? = "welcome_page,success_page,failure_page,questions.possible_answers"
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case questions
        case welcomePage = "welcome_page"
        case successPage = "success_page"
        case failurePage = "failure_page"
    }
}
