//
//  ConsentUserDataSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/06/2020.
//

import Foundation

struct ConsentUserDataSection {
    let id: String
    let type: String
    
    let pages: [Page]
    let successPage: Page?
}

extension ConsentUserDataSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
pages.link_modal,\
success_page.link_1,\
success_page.link_2
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pages
        case successPage = "success_page"
    }
}
