//
//  User.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 25/09/2020.
//

import Foundation

struct UserFlag: Codable {
    let id: String
    let type: String
    let name: String
}

extension UserFlag: JSONAPIMappable {
    
    static var includeList: String? = """
user_flag
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
    }
}

struct User: Codable {
    let id: String
    let type: String
    let phoneNumber: String?
    let email: String
    let isOnboardingCompleted: Bool
    let daysInStudy: Int
    let identities: [String]
    let points: Int
    @ExcludeInvalidCodable
    var agreedPermissions: [SystemPermission]
    @TimeZoneCodable
    var timeZone: TimeZone?
    @FailableCodable
    var customData: [UserInfoParameter]?
    let userPhases: [UserPhase]?
    let studyWalkthroughDone: Bool
    var userFlags: [UserFlag]
    var terraRefID: String?
    
}

extension User: JSONAPIMappable {
    static var includeList: String? = """
user_study_phases,\
user_study_phases.start_at,\
user_study_phases.end_at,\
user_study_phases.study_phase,\
user_study_phases.study_phase.name,\
user_flags
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case phoneNumber = "phone_number"
        case email
        case isOnboardingCompleted = "on_boarding_completed"
        case daysInStudy = "days_in_study"
        case identities
        case points
        case agreedPermissions = "agreed_permissions"
        case timeZone = "time_zone"
        case customData = "custom_data"
        case userPhases = "user_study_phases"
        case studyWalkthroughDone = "study_walkthrough_done"
        case userFlags = "user_flags"
        case terraRefID = "terra_reference_id"
    }
}
