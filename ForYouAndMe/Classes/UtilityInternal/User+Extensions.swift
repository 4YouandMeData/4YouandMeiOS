//
//  User+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 07/10/2020.
//

import Foundation

extension User {
    
    func getFeedTimeInterval(repository: Repository) -> TimeInterval? {
        
        guard let date = self.getFeedDate(repository: repository) else {
            return nil
        }
        switch repository.currentPhaseType {
        case Constants.UserInfo.PostDeliveryPhaseType:
            return Date().timeIntervalSince(date)
        default:
            let referenceDate = date.addingTimeInterval(-(60 * 60 * 24 * 280))
            let interval = Date().timeIntervalSince(referenceDate)
            guard interval > 0 else {
                return nil
            }
            return interval
        }
    }
    
    func getFeedTitle(repository: Repository) -> String {
        guard let interval = self.getFeedTimeInterval(repository: repository) else {
            return ""
        }
        switch repository.currentPhaseType {
        case Constants.UserInfo.PostDeliveryPhaseType: return StringsProvider.string(forKey: .tabFeedTitlePhase1)
        default:
            let trimester = Int((interval / (60 * 60 * 24 * 31 * 3)).rounded(.up))
            let formatter = NumberFormatter()
            formatter.numberStyle = .ordinal
            guard let trimesterOrdinal = formatter.string(from: NSNumber(value: trimester)) else {
                return ""
            }
            return StringsProvider.string(forKey: .tabFeedTitle, withParameters: [trimesterOrdinal.uppercased()])
        }
    }
    
    func getFeedSubtitle(repository: Repository) -> String {
        guard let interval = self.getFeedTimeInterval(repository: repository) else {
            return ""
        }
        let week = Int((interval / (60 * 60 * 24 * 7)).rounded(.up))
        return StringsProvider.string(forKey: .tabFeedSubtitle, withParameters: ["\(week)"])
    }
    
    func getFeedDate(repository: Repository) -> Date? {
        let identifier = Constants.UserInfo.getFeedDateIdentifier(phaseType: repository.currentPhaseType)
        return self.customData?
            .first(where: {$0.identifier == identifier && $0.type == .date})?
            .currentDate
    }
    
    mutating func updateUserInfoParameters(_ userInfoParameters: [UserInfoParameter]) {
        self.customData = userInfoParameters
    }
    
    func getHasAgreedTo(systemPermission: SystemPermission) -> Bool {
        return self.agreedPermissions.contains(systemPermission)
    }
}
