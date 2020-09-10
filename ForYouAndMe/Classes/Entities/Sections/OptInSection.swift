//
//  OptInSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/2020.
//

import Foundation

struct OptInSection {
    let id: String
    let type: String

    let pages: [Page]
    let welcomePage: Page
    let optInPermissions: [OptInPermission]
    let successPage: Page?
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
