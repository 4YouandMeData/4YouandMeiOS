//
//  User+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 07/10/2020.
//

import Foundation

// This extension is extremely specific to the Bump study.
// It is also currently very fragile, since it's based on a lot of assumptions
// (this has been specifically requested).
// TODO: Generalize as soon as possible
extension User {
    
    func getFeedTimeInterval(repository: Repository) -> TimeInterval? {
        
        guard let date = self.getFeedDate(repository: repository) else {
            return nil
        }
        switch repository.currentPhaseIndex {
        case Constants.UserInfo.PostDeliveryPhaseIndex:
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
        switch repository.currentPhaseIndex {
        case Constants.UserInfo.PostDeliveryPhaseIndex:
            return StringsProvider.string(forKey: .tabFeedTitle,
                                          forPhaseIndex: repository.currentPhaseIndex)
        default:
            guard let interval = self.getFeedTimeInterval(repository: repository) else {
                return ""
            }
            
            var parameters: [String] = []
            let trimester = Int((interval / (60 * 60 * 24 * 31 * 3)).rounded(.up))
            let formatter = NumberFormatter()
            formatter.numberStyle = .ordinal

            if let trimesterOrdinal = formatter.string(from: NSNumber(value: trimester)) {
                parameters = [trimesterOrdinal.uppercased()]
            }
            
            return StringsProvider.string(forKey: .tabFeedTitle,
                                          withParameters: parameters,
                                          forPhaseIndex: repository.currentPhaseIndex)
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
        switch repository.currentPhaseIndex {
        case Constants.UserInfo.PreDeliveryPhaseIndex:
            return self.customData?
                .first(where: {$0.identifier == Constants.UserInfo.PreDeliveryParameterIdentifier && $0.type == .date})?
                .currentDate
        case Constants.UserInfo.PostDeliveryPhaseIndex:
            return repository.currentUserPhase?.startAt
        default:
            return nil
        }
    }
    
    mutating func updateUserInfoParameters(_ userInfoParameters: [UserInfoParameter]) {
        self.customData = userInfoParameters
    }
    
    func getHasAgreedTo(systemPermission: SystemPermission) -> Bool {
        return self.agreedPermissions.contains(systemPermission)
    }
}
