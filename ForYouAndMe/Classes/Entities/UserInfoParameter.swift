//
//  UserInfoParameter.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/09/2020.
//

import Foundation

enum UserInfoParameterType: String, Codable {
    case string
    case date
    case items
}

struct UserInfoParameterItem: Codable {
    let identifier: String
    let value: String
}

struct UserInfoParameter: Codable {
    let identifier: String
    let name: String
    let value: String?
    let phaseType: PhaseType?
    let type: UserInfoParameterType
    let items: [UserInfoParameterItem]
    
    var currentStringValue: String? { self.value }
    var currentItemIdentifier: String? { self.value }
    var currentDate: Date? {
        guard let value = value else { return nil }
        return DateStrategy.dateFormatter.date(from: value)
    }
    
    static func create(fromParameter parameter: UserInfoParameter, withValue value: String?) -> UserInfoParameter {
        return UserInfoParameter(identifier: parameter.identifier,
                                 name: parameter.name,
                                 value: value,
                                 phaseType: parameter.phaseType,
                                 type: parameter.type,
                                 items: parameter.items)
    }
}

extension UserInfoParameter {
    enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case value
        case phaseType = "phase"
        case type
        case items
    }
}

struct UserInfoParameterRequest {
    let parameter: UserInfoParameter
    let value: String?
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
