//
//  UserSettings.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 08/04/21.
//

import Foundation

struct UserSettings {
    
    let id: String
    let type: String
    
    var secondsFromMidnight: Int?
    var notificationTime: Int?
}

extension UserSettings: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case secondsFromMidnight = "daily_survey_time_seconds_since_midnight"
        case notificationTime = "notification_time"
    }
}
