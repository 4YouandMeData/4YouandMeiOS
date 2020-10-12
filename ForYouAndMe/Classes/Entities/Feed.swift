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
    case educational(educational: Educational)
    case alert(alert: Alert)
    case rewards(rewards: Rewards)
    
    var schedulableType: String {
        switch self {
        case .quickActivity: return "quick_activity"
        case .activity: return "activity"
        case .survey: return "survey"
        case .educational: return "educational"
        case .alert: return "alert"
        case .rewards: return "rewards"
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
    var schedulable: Schedulable
}

extension Feed: JSONAPIMappable {
    static var includeList: String? = """
schedulable,\
schedulable.quick_activity_options
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case fromDate = "from"
        case toDate = "to"
        case schedulable
    }
}

enum FeedError: Error {
    case invalidSchedulable
}

@propertyWrapper
struct SchedulableDecodable: Decodable {
    
    var wrappedValue: Schedulable
    
    init(wrappedValue: Schedulable) {
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
        } else if let educational = try? container.decode(Educational.self),
                  Schedulable.educational(educational: educational).schedulableType == educational.type {
            self.wrappedValue = .educational(educational: educational)
        } else if let alert = try? container.decode(Alert.self),
                  Schedulable.alert(alert: alert).schedulableType == alert.type {
            self.wrappedValue = .alert(alert: alert)
        } else if let rewards = try? container.decode(Rewards.self),
                  Schedulable.rewards(rewards: rewards).schedulableType == rewards.type {
            self.wrappedValue = .rewards(rewards: rewards)
        } else {
            // TODO: Add all expected cases
            throw FeedError.invalidSchedulable
        }
    }
}
