//
//  StudyInfoSection.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 08/10/2020.
//

import Foundation

struct StudyInfoSection {
    let id: String
    let type: String
    
    let pages: [Page]
    let rewardPage: Page?
    var faqPage: Page?
    let contactsPage: Page?
    let walkThroughPage: Page?
}

extension StudyInfoSection: JSONAPIMappable {
    static var includeList: String? = """
pages,\
reward_page,\
information_page,\
faq_page,\
walkthrough_page
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case pages
        case rewardPage = "reward_page"
        case faqPage = "faq_page"
        case contactsPage = "information_page"
        case walkThroughPage = "walkthrough_page"
    }
}
