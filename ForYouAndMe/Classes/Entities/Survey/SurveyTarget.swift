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
    @FailableEnumStringDecodable
    var criteria: SurveyTargetCriteria?
    let minimum: Int?
    let maximum: Int?
    let questionId: String?
    @NilIfEmptyString
    var answerId: String?
    @NilIfEmptyString
    var blockId: String?
}

extension SurveyTarget: PlainDecodable {
    enum CodingKeys: String, CodingKey {
        case criteria
        case minimum = "min"
        case maximum = "max"
        case questionId = "question_id"
        case answerId = "answer_id"
        case blockId = "block_id"
    }
}
