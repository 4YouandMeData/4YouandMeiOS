//
//  GradientPalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

enum GradientViewType {
    case defaultBackground
    
    fileprivate var colors: [UIColor] {
        switch self {
        case .defaultBackground: return [ColorPalette.color(withType: .primary), ColorPalette.color(withType: .gradientPrimaryEnd)]
        }
    }
    
    fileprivate var locations: [Double] {
        switch self {
        case .defaultBackground: return [0.0, 1.0]
        }
    }
    
    fileprivate var startPoint: CGPoint {
        switch self {
        case .defaultBackground: return CGPoint(x: 0.0, y: 0.5)
        }
    }
    
    fileprivate var endPoint: CGPoint {
        switch self {
        case .defaultBackground: return CGPoint(x: 1.0, y: 0.5)
        }
    }
}

extension GradientView {
    convenience init(type: GradientViewType) {
        self.init(colors: type.colors, locations: type.locations, startPoint: type.startPoint, endPoint: type.endPoint)
    }
}
