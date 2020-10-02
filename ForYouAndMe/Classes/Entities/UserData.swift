//
//  UserData.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 01/10/2020.
//

import Foundation

struct UserData {
    let id: String
    let type: String
    
    @NilIfEmptyString
    var title: String?
    @NilIfEmptyString
    var body: String?
    let stars: Double
}

extension UserData: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case stars
    }
}
