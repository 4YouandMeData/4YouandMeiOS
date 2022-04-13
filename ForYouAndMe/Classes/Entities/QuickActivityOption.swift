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
    @URLDecodable
    var image: URL?
    @URLDecodable
    var selectedImage: URL?
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

extension QuickActivityOption {
    var networkResultData: TaskNetworkResult {
        var resultData: [String: Any] = [:]
        resultData["selected_quick_activity_option_id"] = Int(self.id)
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}
