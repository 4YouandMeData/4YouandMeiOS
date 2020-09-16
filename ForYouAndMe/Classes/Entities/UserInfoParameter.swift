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
    let name: String
    let value: String
    let type: UserInfoParameterType
    let items: [UserInfoParameterItem]
}
