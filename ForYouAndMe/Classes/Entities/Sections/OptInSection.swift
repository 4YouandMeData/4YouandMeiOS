//
//  OptInSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/2020.
//

import Foundation

// FUAM-4045. Welcome and success pages are optional: a study may configure an
// opt-in section that starts straight at the first permission and/or ends
// without a thank-you page. When welcome page, success page and (iOS-visible)
// permissions are all missing, the section has nothing to show and is skipped
// entirely — same outcome as the backend omitting the section altogether.
// This optional-pages / skip-when-empty pattern is meant to be extended to the
// other onboarding sections (see FUAM-4044); keep the section model exposing an
// `isEmpty`-style predicate and the coordinator's `getStartingPage()` nil-safe
// so the same wiring in `OnboardingSection` can be reused as-is.
struct OptInSection {
    let id: String
    let type: String

    let pages: [Page]
    let welcomePage: Page?
    let optInPermissions: [OptInPermission]
    let successPage: Page?
}

extension OptInSection {
    /// FUAM-4045. `true` when the section would present no screen at all:
    /// no welcome page, no success page and no permission renderable on iOS
    /// (`platforms` gating, FUAM-3364). Linked `pages` are only reachable from
    /// the welcome page, so they cannot make an otherwise-empty section
    /// presentable.
    var isEmpty: Bool {
        return self.welcomePage == nil
            && self.successPage == nil
            && false == self.optInPermissions.contains { $0.isAvailableOnIOS }
    }
}

extension OptInSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
pages.link_modal,\
welcome_page.link_1,\
welcome_page.link_2,\
success_page,\
permissions
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pages
        case optInPermissions = "permissions"
        case welcomePage = "welcome_page"
        case successPage = "success_page"
    }
}
