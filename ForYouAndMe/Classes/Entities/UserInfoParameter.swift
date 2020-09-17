//
//  UserInfoParameter.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/09/2020.
//

import Foundation

enum UserInfoParameterType {
    case string
    case date
    case items
}

struct UserInfoParameterItem {
    let identifier: String
    let value: String
}

struct UserInfoParameter {
    let identifier: String
    let name: String
    let value: String
    let type: UserInfoParameterType
    let items: [UserInfoParameterItem]
}

extension UserInfoParameter: Hashable, Equatable {
    static func == (lhs: UserInfoParameter, rhs: UserInfoParameter) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.identifier)
    }
}

extension UserInfoParameterItem: Hashable, Equatable {
    static func == (lhs: UserInfoParameterItem, rhs: UserInfoParameterItem) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.identifier)
    }
}
