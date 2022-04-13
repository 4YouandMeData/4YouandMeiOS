//
//  Survey.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 05/08/2020.
//

import Foundation

struct Survey {
    let id: String
    let type: String
    
    @NilIfEmptyString
    var title: String?
    @NilIfEmptyString
    var body: String?
    @URLDecodable
    var image: URL?
    @NilIfEmptyString
    var buttonText: String?
    
    @ColorDecodable
    var startColor: UIColor?
    @ColorDecodable
    var endColor: UIColor?
    @ColorDecodable
    var cardColor: UIColor?
}

extension Survey: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body = "description"
        case image
        case buttonText = "task_action_button_label"
        case startColor = "start_color"
        case endColor = "end_color"
        case cardColor = "card_color"
    }
}
