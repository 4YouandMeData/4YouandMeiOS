//
//  User+Mappable.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 26/09/2020.
//

import Mapper

extension User: Mappable {
    
    init(map: Mapper) throws {
        try self.id = map.from("id")
        try self.studyId = map.from("study_id")
        try self.phoneNumber = map.from("phone_number")
        self.email = map.optionalFrom("email")
        try self.isOnboardingCompleted = map.from("onboarding_completed")
    }
}
