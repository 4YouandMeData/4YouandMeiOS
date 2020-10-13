//
//  Alert.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/10/2020.
//

import Foundation

struct Alert {
    let id: String
    let type: String
    
    @NilIfEmptyString
    var title: String?
    @NilIfEmptyString
    var body: String?
    @ImageDecodable
    var image: UIImage?
    @NilIfEmptyString
    var buttonText: String?
    @NilIfEmptyString
    var urlString: String?
    
    @ColorDecodable
    var startColor: UIColor?
    @ColorDecodable
    var endColor: UIColor?
    @ColorDecodable
    var cardColor: UIColor?
}

extension Alert: JSONAPIMappable {
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
