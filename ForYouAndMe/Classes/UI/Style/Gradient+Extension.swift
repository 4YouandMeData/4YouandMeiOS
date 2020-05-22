//
//  GradientPalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

enum GradientViewType {
    case primaryBackground
    
    var colors: [UIColor] {
        switch self {
        case .primaryBackground: return [ColorPalette.color(withType: .primary), ColorPalette.color(withType: .gradientPrimaryEnd)]
        }
    }
    
    var locations: [Double] {
        switch self {
        case .primaryBackground: return [0.0, 1.0]
        }
    }
    
    var startPoint: CGPoint {
        switch self {
        case .primaryBackground: return CGPoint(x: 0.0, y: 0.5)
        }
    }
    
    var endPoint: CGPoint {
        switch self {
        case .primaryBackground: return CGPoint(x: 1.0, y: 0.5)
        }
    }
}

extension GradientView {
    convenience init(type: GradientViewType) {
        self.init(colors: type.colors, locations: type.locations, startPoint: type.startPoint, endPoint: type.endPoint)
    }
}
