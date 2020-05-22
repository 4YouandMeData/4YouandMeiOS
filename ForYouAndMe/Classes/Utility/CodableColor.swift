//
//  CodableColor.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

struct CodableColor: Codable {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0

    var uiColor: UIColor {
        return UIColor(red: self.red, green: self.green, blue: self.blue, alpha: self.alpha)
    }

    init(uiColor: UIColor) {
        uiColor.getRed(&self.red, green: &self.green, blue: &self.blue, alpha: &self.alpha)
    }
}
