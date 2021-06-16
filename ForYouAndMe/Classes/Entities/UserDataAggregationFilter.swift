//
//  UserDataAggregationFilter.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/06/21.
//

import Foundation

struct UserDataAggregationFilter: Codable {
    let identifier: String
    let title: String
    
    init(withIdentifier identifier: String, title: String) {
        self.identifier = identifier
        self.title = title
    }
}

extension Array where Element == UserDataAggregation {
    var filterData: [UserDataAggregationFilter] {
        return self.compactMap {
            guard let title = $0.title else {
                return nil
            }
            return UserDataAggregationFilter(withIdentifier: $0.id, title: title)
        }
    }
}
