//
//  SurveyTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation

struct SurveyTask {
    let id: String
    let type: String
    
    let pages: [Page]
    let welcomePage: Page?
    @ExcludeInvalid
    var questions: [SurveyQuestion]
    let successPage: Page?
}

extension SurveyTask: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pages
        case welcomePage = "intro_page"
        case questions
        case successPage = "success_page"
    }
}

extension SurveyTask: Hashable, Equatable {
    static func == (lhs: SurveyTask, rhs: SurveyTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
