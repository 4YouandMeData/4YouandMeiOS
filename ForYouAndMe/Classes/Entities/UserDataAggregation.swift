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
    let strategy: String
    
    fileprivate let chartData: ChartData
    
    var chartDataContent: ChartDataContent {
        return self.chartData.getData(forStrategy: self.strategy)
    }
    
    var chartDataXlabels: ChartDataXLabels {
        return self.chartData.xLabels
    }
    
    var chartDataYlabels: ChartDataYLabels {
        return self.chartData.yLabels
    }
}

extension UserDataAggregation: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case color
        case chartData = "data"
        case strategy
    }
}

fileprivate extension ChartData {
    func getData(forStrategy strategy: String) -> ChartDataContent {
        // Temporary conversion of Bodyport data from kg to lbs (since current studies are all in US / Canada)
        // TODO: Remove when the choice of all unit of measure will be given to the user from within the app.
        if strategy.contains("bodyport_weight") {
            let fromUnit = UnitMass.kilograms
            let toUnit = UnitMass.pounds
            return self.data.map { data in
                guard let data = data else {
                    return nil
                }
                return Measurement(value: data, unit: fromUnit).converted(to: toUnit).value
            }
        } else {
            return self.data
        }
    }
}
