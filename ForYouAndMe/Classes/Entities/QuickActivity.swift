//
//  QuickActivity.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 05/08/2020.
//

import Foundation

struct QuickActivity {
    let id: String
    let type: String
    
    @NilIfEmptyString
    var title: String?
    @NilIfEmptyString
    var body: String?
    @NilIfEmptyString
    var buttonText: String?
    let options: [QuickActivityOption]
    
    @ColorDecodable
    var startColor: UIColor?
    @ColorDecodable
    var endColor: UIColor?
}

extension QuickActivity: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body = "description"
        case buttonText = "task_action_button_label"
        case options = "quick_activity_options"
        case startColor = "start_color"
        case endColor = "end_color"
    }
}
