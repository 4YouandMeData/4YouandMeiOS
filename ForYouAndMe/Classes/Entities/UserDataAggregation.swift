//
//  UserDataAggregation.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 01/10/2020.
//

import Foundation

struct UserDataAggregation {
    let id: String
    let type: String
    
    @NilIfEmptyString
    var title: String?
    @ColorDecodable
    var color: UIColor?
    
    let chartData: ChartData
}

extension UserDataAggregation: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case color
        case chartData = "data"
    }
}
