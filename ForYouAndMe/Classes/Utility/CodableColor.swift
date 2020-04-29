//
//  CodableColor.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//

import UIKit

struct CodableColor: Codable {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0

    var uiColor: UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    init(uiColor: UIColor) {
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    }
}
