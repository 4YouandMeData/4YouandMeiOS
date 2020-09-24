//
//  SurveyGroup.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation

struct SurveyGroup {
//    let id: String
//    let type: String
    
    let surveys: [SurveyTask]
}

extension SurveyGroup: PlainDecodable {
    enum CodingKeys: String, CodingKey {
//        case id
//        case type
        case surveys
    }
}
