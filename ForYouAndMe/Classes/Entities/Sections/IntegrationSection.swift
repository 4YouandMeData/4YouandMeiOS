//
//  IntegrationSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

// FUAM-4045 / FUAM-4036. Same optional-pages / skip-when-empty contract as
// `OptInSection` (see the comment there, and FUAM-4044 for extending the
// pattern to the other onboarding sections). Note the backend answers this
// endpoint with an empty `Integration` record (HTTP 200, `"id": null`) when the
// study has no integration section configured, so the empty case is not
// hypothetical: `allowsNullIdentifier` below lets that payload decode.
struct IntegrationSection {
    let id: String
    let type: String

    let pages: [Page]
    let welcomePage: Page?
    let successPage: Page?
}

extension IntegrationSection {
    /// FUAM-4036. The section's entry point: the welcome page, else the success
    /// page (a success-only integration shows just that page, whose primary
    /// button completes the step). The loose `pages` are only ever reached
    /// through page links, never as a starting step nor a fallback.
    var startingPage: Page? {
        return self.welcomePage ?? self.successPage
    }

    /// FUAM-4036. `true` when the section would present no screen at all: no
    /// welcome page and no success page. It is then skipped, no matter what the
    /// loose `pages` contain.
    var isEmpty: Bool {
        return self.startingPage == nil
    }

    /// FUAM-4036. Target of a page link. The success page id resolves to the
    /// success page (so it is shown once, through the success handling, even if
    /// it is not among `pages`); an id that is not in the payload resolves to
    /// nil, which the coordinator treats as the end of the link chain.
    func linkedPage(forPageRef pageRef: PageRef) -> Page? {
        if let successPage = self.successPage, successPage.id == pageRef.id {
            return successPage
        }
        return self.pages.getPage(forPageRef: pageRef)
    }
}

extension IntegrationSection: JSONAPIMappable {
    // FUAM-4036. A study with no integration answers 200 with an empty resource carrying a null id.
    static let allowsNullIdentifier: Bool = true
    
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
