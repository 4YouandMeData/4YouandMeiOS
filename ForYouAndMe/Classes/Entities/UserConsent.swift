//
//  UserConsent.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 31/03/25.
//

import Foundation

struct UserConsent: Decodable {
    let id: String
    let type: String
    let firstName: String
    let lastName: String
    let agree: Bool
    let email: String
    
    @ImageDecodable
    var image: UIImage?
    
}

extension UserConsent: JSONAPIMappable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case firstName = "first_name"
        case lastName = "last_name"
        case agree
        case email
        case image = "signature_file"
    }
}
