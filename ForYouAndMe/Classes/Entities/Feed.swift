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
    case rewards(rewards: Rewards)
    
    var notifiableType: String {
        switch self {
        case .educational: return "feed_educational"
        case .alert: return "feed_alert"
        case .rewards: return "feed_reward"
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

extension Feed: JSONAPIMappable {
    static var includeList: String? = """
schedulable,\
schedulable.quick_activity_options,\
notifiable
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case fromDate = "from"
        case toDate = "to"
        case schedulable
        case notifiable
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
        } else if let rewards = try? container.decode(Rewards.self),
                  Notifiable.rewards(rewards: rewards).notifiableType == rewards.type {
            self.wrappedValue = .rewards(rewards: rewards)
        } else {
            self.wrappedValue = nil
        }
    }
}

