//
//  User.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 25/09/2020.
//

import Foundation
import Mapper

struct User {
    
    let id: Int
    let studyId: Int
    let phoneNumber: String
    var email: String?
}

extension User: Codable {
    
    private enum CodingKeys: String, CodingKey {
        case id
        case studyId
        case phoneNumber
        case email
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.studyId = try container.decode(Int.self, forKey: .studyId)
        self.phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        self.email = try container.decode(String.self, forKey: .email)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.studyId, forKey: .studyId)
        try container.encode(self.phoneNumber, forKey: .phoneNumber)
        try container.encode(self.email, forKey: .email)
    }
}
