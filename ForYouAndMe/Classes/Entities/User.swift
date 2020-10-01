//
//  User.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 25/09/2020.
//

import Foundation
import Mapper

struct User: Codable {
    
    let id: Int
    let studyId: Int
    let phoneNumber: String
    let email: String?
    let isOnboardingCompleted: Bool
}
