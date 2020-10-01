//
//  ChartData.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 01/10/2020.
//

import Foundation

struct ChartData {
    let data: [Double?]
    let xLabels: [String]
    let yLabels: [String]
}

extension ChartData: Decodable {
    enum CodingKeys: String, CodingKey {
        case data
        case xLabels = "x_labels"
        case yLabels = "y_labels"
    }
}
