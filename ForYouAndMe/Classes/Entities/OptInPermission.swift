//
//  OptInPermission.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/2020.
//

import Foundation

enum SystemPermission: String, Codable {
    case location
    case health
}

struct OptInPermission {
    let id: String
    let type: String

    let title: String
    let body: String
    let grantText: String
    let denyText: String
    @ExcludeInvalid
    var systemPermissions: [SystemPermission]
    let imageData: Data?
    let isMandatory: Bool
    @NilIfEmptyString
    var mandatoryText: String?
}

extension OptInPermission: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case grantText = "agree_text"
        case denyText = "disagree_text"
        case systemPermissions = "system_permissions"
        case imageData = "image"
        case isMandatory = "is_mandatory"
        case mandatoryText = "mandatory_text"
    }
}

extension OptInPermission {
    var image: UIImage? {
        if let data = self.imageData {
            return UIImage(data: data)
        } else {
            return nil
        }
    }
}
