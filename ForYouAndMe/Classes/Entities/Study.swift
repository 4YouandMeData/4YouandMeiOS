//
//  Study.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 20/03/23.
//

import Foundation

struct Study: Codable {
    let id: String
    let type: String
    let name: String
    let phases: [Phase]?
}

extension Study: JSONAPIMappable {
    static var includeList: String? = """
study_phases.name,\
study_phases.faq_page
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case phases = "study_phases"
    }
}
