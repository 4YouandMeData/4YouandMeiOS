//
//  UserSettings.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 08/04/21.
//

import Foundation

/// Menstrual baseline answer to "Have you had a menstrual period in the past
/// 3 months?" — drives both the inline onboarding (FUAM-2937) and the Settings
/// panel (FUAM-2936). BE schema (FUAM-2929) accepts yes/no/unsure as strings.
enum MenstrualHadPeriod3Mo: String, CaseIterable, Codable {
    case yes
    case no
    case unsure
}

struct UserSettings {

    let id: String
    let type: String

    var secondsFromMidnight: Int?
    var notificationTime: Int?

    /// FUAM-2929: nullable enum (yes/no/unsure) — set via inline onboarding
    /// or Settings. When `.no`, the BE trigger suppresses the daily feed card.
    var menstrualHadPeriod3Mo: MenstrualHadPeriod3Mo?

    /// FUAM-2929: nullable date (must be in the past) — start of last period.
    /// BE serializes as `YYYY-MM-DD`.
    var menstrualLastPeriodDate: Date?
}

extension UserSettings: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case secondsFromMidnight = "daily_survey_time_seconds_since_midnight"
        case notificationTime = "notification_time"
        case menstrualHadPeriod3Mo = "menstrual_had_period_3mo"
        case menstrualLastPeriodDate = "menstrual_last_period_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.secondsFromMidnight = try container.decodeIfPresent(Int.self, forKey: .secondsFromMidnight)
        self.notificationTime = try container.decodeIfPresent(Int.self, forKey: .notificationTime)
        self.menstrualHadPeriod3Mo = try container.decodeIfPresent(MenstrualHadPeriod3Mo.self,
                                                                    forKey: .menstrualHadPeriod3Mo)
        // BE returns the date as `YYYY-MM-DD`. ISO8601DateFormatter rejects
        // date-only strings, so use a calendar-only DateFormatter.
        if let dateStr = try container.decodeIfPresent(String.self, forKey: .menstrualLastPeriodDate) {
            self.menstrualLastPeriodDate = UserSettings.dateOnlyFormatter.date(from: dateStr)
        } else {
            self.menstrualLastPeriodDate = nil
        }
    }

    static let dateOnlyFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()
}

extension UserSettings {
    /// FUAM-2937 gate: returns `true` when opening the menstrual diary
    /// wizard should be intercepted by the inline baseline onboarding.
    /// Triggers only when the baseline has never been configured (`nil`).
    /// Once the user has answered (yes/no/unsure) the baseline is considered
    /// captured and the wizard proceeds without re-collecting it — for `.no`
    /// the BE-side trigger and the client-side filter already suppress the
    /// pinned feed card, so re-prompting on FAB / settings entry is noise.
    var needsMenstrualOnboarding: Bool {
        return menstrualHadPeriod3Mo == nil
    }
}
