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
    
    let pages: [InfoPage]
    let successPage: InfoPage?
}

extension ConsentUserDataSection: JSONAPIMappable {
    static var includeList: String? = """
pages.link_1,\
pages.link_2,\
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
