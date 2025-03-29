//
//  ProfilingOption.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 27/03/25.
//

import Foundation

enum ProfilingOptionType: String {
    case success
    case next
    case failure
}

struct ProfilingOption: Decodable {
    let id: String
    let type: String
    
    @EnumStringDecodable
    var navigation: ProfilingOptionType
    let text: String
    let position: Int
}

extension ProfilingOption: JSONAPIMappable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case navigation
        case text
        case position
    }
}

extension ProfilingOption: Equatable {
    static func == (lhs: ProfilingOption, rhs: ProfilingOption) -> Bool {
        return lhs.id == rhs.id
    }
}
