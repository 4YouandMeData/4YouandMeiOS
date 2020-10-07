//
//  User+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 07/10/2020.
//

import Foundation

extension User {
    var feedTitle: String {
        guard let date = self.feedDate else {
            return ""
        }
        let interval = date.timeIntervalSince(Date())
        guard interval > 0 else {
            return ""
        }
        let trimester = Int((interval / (60 * 60 * 24 * 31 * 3)).rounded(.up))
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        guard let trimesterOrdinal = formatter.string(from: NSNumber(value: trimester)) else {
            return ""
        }
        return StringsProvider.string(forKey: .tabFeedTitle, withParameters: [trimesterOrdinal.uppercased()])
    }
    var feedSubtitle: String {
        guard let date = self.feedDate else {
            return ""
        }
        let interval = date.timeIntervalSince(Date())
        guard interval > 0 else {
            return ""
        }
        let week = Int((interval / (60 * 60 * 24 * 7)).rounded(.up))
        return StringsProvider.string(forKey: .tabFeedSubtitle, withParameters: ["\(week)"])
    }
    var feedDate: Date? {
        return self.customData?
            .first(where: {$0.identifier == Constants.UserInfo.FeedTitleParameterIdentifier && $0.type == .date})?
            .currentDate
    }
    
    mutating func updateUserInfoParameters(_ userInfoParameters: [UserInfoParameter]) {
        self.customData = userInfoParameters
    }
}
