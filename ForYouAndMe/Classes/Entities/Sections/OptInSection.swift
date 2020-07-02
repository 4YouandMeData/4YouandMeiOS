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

    let pages: [InfoPage]
    let welcomePage: InfoPage
    let optInPermissions: [OptInPermission]
    let successPage: InfoPage?
}

extension OptInSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
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
