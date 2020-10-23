//
//  Feed.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import Foundation

enum Schedulable {
    case quickActivity(quickActivity: QuickActivity)
    case activity(activity: Activity)
    case survey(survey: Survey)
    
    var schedulableType: String {
        switch self {
        case .quickActivity: return "quick_activity"
        case .activity: return "activity"
        case .survey: return "survey"
        }
    }
}

enum Notifiable {
    case educational(educational: Educational)
    case alert(alert: Alert)
    case reward(reward: Reward)
    
    var notifiableType: String {
        switch self {
        case .educational: return "feed_educational"
        case .alert: return "feed_alert"
        case .reward: return "feed_reward"
        }
    }
}

struct Feed {
    let id: String
    let type: String
    
    @DateValue<ISO8601Strategy>
    var fromDate: Date
    @DateValue<ISO8601Strategy>
    var toDate: Date
    
    @SchedulableDecodable
    var schedulable: Schedulable?
    
    @NotifiableDecode
    var notifiable: Notifiable?
}

enum FeedParsingError: Error {
    case missingBothSchedulableAndNotifiable
}

extension Feed: JSONAPIMappable {
    static var includeList: String? = """
schedulable,\
schedulable.quick_activity_options,\
notifiable,\
schedulable.pages.link_1,\
schedulable.welcome_page.link_1,\
schedulable.success_page
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case fromDate = "from"
        case toDate = "to"
        case schedulable
        case notifiable
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.toDate = try container.decode(DateValue<ISO8601Strategy>.self, forKey: .toDate).wrappedValue
        self.fromDate = try container.decode(DateValue<ISO8601Strategy>.self, forKey: .fromDate).wrappedValue
        self.schedulable = try? container.decodeIfPresent(SchedulableDecodable.self, forKey: .schedulable)?.wrappedValue
        self.notifiable = try? container.decodeIfPresent(NotifiableDecode.self, forKey: .notifiable)?.wrappedValue
        guard self.schedulable != nil || self.notifiable != nil else {
            throw FeedParsingError.missingBothSchedulableAndNotifiable
        }
    }
}

@propertyWrapper
struct SchedulableDecodable: Decodable {
    
    var wrappedValue: Schedulable?
    
    init(wrappedValue: Schedulable?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let activity = try? container.decode(Activity.self),
            Schedulable.activity(activity: activity).schedulableType == activity.type {
            self.wrappedValue = .activity(activity: activity)
        } else if let quickActivity = try? container.decode(QuickActivity.self),
            Schedulable.quickActivity(quickActivity: quickActivity).schedulableType == quickActivity.type {
            self.wrappedValue = .quickActivity(quickActivity: quickActivity)
        } else if let survey = try? container.decode(Survey.self),
            Schedulable.survey(survey: survey).schedulableType == survey.type {
            self.wrappedValue = .survey(survey: survey)
        } else {
            self.wrappedValue = nil
        }
    }
}

@propertyWrapper
struct NotifiableDecode: Decodable {
    
    var wrappedValue: Notifiable?
    
    init(wrappedValue: Notifiable?) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let educational = try? container.decode(Educational.self),
                  Notifiable.educational(educational: educational).notifiableType == educational.type {
            self.wrappedValue = .educational(educational: educational)
        } else if let alert = try? container.decode(Alert.self),
                  Notifiable.alert(alert: alert).notifiableType == alert.type {
            self.wrappedValue = .alert(alert: alert)
        } else if let reward = try? container.decode(Reward.self),
                  Notifiable.reward(reward: reward).notifiableType == reward.type {
            self.wrappedValue = .reward(reward: reward)
        } else {
            self.wrappedValue = nil
        }
    }
}
