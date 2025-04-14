//
//  OnboardingQuestionsSection.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 27/03/25.
//

import Foundation

struct OnboardingQuestionsSection {
    let id: String
    let type: String

    let pages: [Page]

    @ExcludeInvalid
    var questions: [ProfilingQuestion]
    
    let welcomePage: Page?
    let successPage: Page?
    let failurePage: Page?
}

extension OnboardingQuestionsSection: JSONAPIMappable {
    static var includeList: String? = """
pages,\
pages.link_1,\
success_page,\
profiling_questions,\
welcome_page,\
welcome_page.link_1,\
failure_page,\
profiling_questions.profiling_options
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pages
        case questions = "profiling_questions"
        case welcomePage = "welcome_page"
        case successPage = "success_page"
        case failurePage = "failure_page"
    }
}

extension OnboardingQuestionsSection: Hashable, Equatable {
    static func == (lhs: OnboardingQuestionsSection, rhs: OnboardingQuestionsSection) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}

extension OnboardingQuestionsSection {
    
    var isValid: Bool {
        return self.validQuestions.count > 0
    }
    
    var validQuestions: [ProfilingQuestion] {
        return self.questions.filter { $0.isValid }
    }
}
