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

extension User: Mappable {
    
    init(map: Mapper) throws {
        try self.id = map.from("id")
        try self.studyId = map.from("study_id")
        try self.phoneNumber = map.from("phone_number")
        self.email = map.optionalFrom("email")
    }
}
