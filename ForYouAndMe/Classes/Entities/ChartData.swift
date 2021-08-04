//
//  ChartData.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 01/10/2020.
//

import Foundation

typealias ChartDataContent = [Double?]
typealias ChartDataXLabels = [String]
typealias ChartDataYLabels = [String]

struct ChartData {
    let data: ChartDataContent
    let xLabels: ChartDataXLabels
    let yLabels: ChartDataYLabels
}

extension ChartData: Decodable {
    enum CodingKeys: String, CodingKey {
        case data
        case xLabels = "x_labels"
        case yLabels = "y_labels"
    }
}
