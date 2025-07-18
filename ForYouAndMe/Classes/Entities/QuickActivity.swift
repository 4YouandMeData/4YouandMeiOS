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
    @ColorDecodable
    var cardColor: UIColor?
    
    @FailableDecodable
    var skippable: Bool?
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
        case cardColor = "card_color"
        case skippable = "with_optional_flag"
    }
}

extension QuickActivity: Hashable, Equatable {
    static func == (lhs: QuickActivity, rhs: QuickActivity) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
}
