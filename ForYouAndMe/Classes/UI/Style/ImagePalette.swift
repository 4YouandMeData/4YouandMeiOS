//
//  ImagePalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//

import Foundation

enum ImageName: String, CaseIterable {
    case testImage = "test_image"
}

public class ImagePalette {
    
    static func image(withName name: ImageName) -> UIImage? {
        return UIImage(named: name.rawValue) ?? UIImage(named: name.rawValue, in: PodUtils.podDefaultResourceBundle, with: nil)
    }
    
    static func checkImageAvailabilityOnMainBundle() {
        ImageName.allCases.forEach { imageName in
            assert(UIImage(named: imageName.rawValue) != nil, "missing image: \(imageName.rawValue) in current main bundle")
        }
    }
}
