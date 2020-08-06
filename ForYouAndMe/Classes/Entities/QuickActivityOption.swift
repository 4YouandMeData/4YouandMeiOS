//
//  QuickActivityOption.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 06/08/2020.
//

import Foundation

struct QuickActivityOption {
    let id: String
    let type: String
    
    @NilIfEmptyString
    var label: String?
    @ImageDecodable
    var image: UIImage?
    @ImageDecodable
    var selectedImage: UIImage?
}

extension QuickActivityOption: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case label
        case image
        case selectedImage = "selected_image"
    }
}

extension QuickActivityOption: Equatable {
    static func == (lhs: QuickActivityOption, rhs: QuickActivityOption) -> Bool {
        return lhs.id == rhs.id
    }
}
