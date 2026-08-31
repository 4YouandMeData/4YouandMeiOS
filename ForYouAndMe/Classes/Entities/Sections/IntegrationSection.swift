//
//  IntegrationSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

// FUAM-4045. Same optional-pages / skip-when-empty contract as `OptInSection`
// (see the comment there, and FUAM-4044 for extending the pattern to the other
// onboarding sections). Note the backend answers this endpoint with an empty
// `Integration` record when the study has no integration section configured,
// so the empty case is not hypothetical.
struct IntegrationSection {
    let id: String
    let type: String

    let pages: [Page]
    let welcomePage: Page?
    let successPage: Page?
}

extension IntegrationSection {
    /// FUAM-4045. `true` when the section would present no screen at all.
    var isEmpty: Bool {
        return self.welcomePage == nil && self.successPage == nil && self.pages.isEmpty
    }
}

extension IntegrationSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
pages.link_modal,\
welcome_page.link_1,\
welcome_page.link_2,\
success_page
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pages
        case welcomePage = "welcome_page"
        case successPage = "success_page"
    }
}
