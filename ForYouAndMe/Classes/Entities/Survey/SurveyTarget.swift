//
//  SurveyTarget.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation

enum SurveyTargetCriteria: String {
    case range
}

struct SurveyTarget {
//    let id: String
//    let type: String
    
    @EnumStringDecodable
    var criteria: SurveyTargetCriteria?
    let minimum: Double?
    let maximum: Double?
    let questionId: String
}

extension SurveyTarget: Decodable {
    enum CodingKeys: String, CodingKey {
//        case id
//        case type
        case criteria
        case minimum = "min"
        case maximum = "max"
        case questionId = "question_id"
    }
}
