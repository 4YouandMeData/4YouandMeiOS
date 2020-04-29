//
//  FontPalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//

import UIKit

public typealias FontTypeMap = [FontType: String]

public enum FontType: String, CaseIterable {
    case regular
    
    fileprivate var defaultWeight: UIFont.Weight {
        switch self {
        case .regular: return .regular
        }
    }
}

public class FontPalette {
    
    private static var fontTypeMap: FontTypeMap = [:]
    
    public static func initialize(withFontTypeMap fontTypeMap: FontTypeMap) {
        self.fontTypeMap = fontTypeMap
    }
    
    static func font(withSize size: CGFloat, type: FontType = .regular) -> UIFont {
        return UIFont(name: self.fontTypeMap[type] ?? "", size: size) ?? UIFont.systemFont(ofSize: size, weight: type.defaultWeight)
    }
    
    static func checkImageAvailabilityOnMainBundle() {
        ImageName.allCases.forEach { imageName in
            assert(UIImage(named: imageName.rawValue) != nil, "missing image: \(imageName.rawValue) in current main bundle")
        }
    }
}
