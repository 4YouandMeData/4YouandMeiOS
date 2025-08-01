//
//  SurveyQuestionOption.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/09/2020.
//

import Foundation

struct SurveyQuestionOption {
    let id: String
    let type: String
    
    let value: String
    let isNone: Bool?
    let isOther: Bool?
    @ImageDecodable
    var previewImage: UIImage?
    @ImageDecodable
    var fullScreenImage: UIImage?
}

extension SurveyQuestionOption: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value = "text"
        case isNone = "is_none"
        case isOther = "is_other"
        case previewImage = "preview_image"
        case fullScreenImage = "fullscreen_image"
    }
}
