//
//  WearablesSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

struct WearablesSection {
    let id: String
    let type: String

    let pages: [Page]
    let welcomePage: Page
    let successPage: Page?
}

extension WearablesSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
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