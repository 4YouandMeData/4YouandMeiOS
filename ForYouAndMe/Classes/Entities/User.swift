//
//  User.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 25/09/2020.
//

import Foundation

struct User: Codable {
    let id: String
    let type: String
    let phoneNumber: String
    let email: String
    let isOnboardingCompleted: Bool
    let daysInStudy: Int
    let identities: [String]
    let points: Int
    @TimeZoneDecodable
    var timeZone: TimeZone?
    var customData: [UserInfoParameter]?
}

extension User: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case phoneNumber = "phone_number"
        case email
        case isOnboardingCompleted = "on_boarding_completed"
        case daysInStudy = "days_in_study"
        case identities
        case points
        case timeZone = "time_zone"
        case customData = "custom_data"
    }
}
