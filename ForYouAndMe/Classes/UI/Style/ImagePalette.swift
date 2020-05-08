//
//  ImagePalette.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

enum ImageName: String, CaseIterable {
    case setupFailure
    case failure
    case fyamLogoSpecific
    case fyamLogoGeneric
    case mainLogo
    case nextButtonLight
    case backButton
    case checkmark
    case edit
}

public class ImagePalette {
    
    static func image(withName name: ImageName) -> UIImage? {
        return UIImage(named: name.rawValue) ?? UIImage(named: name.rawValue, in: PodUtils.podDefaultResourceBundle, with: nil)
    }
    
    static func checkImageAvailability() {
        ImageName.allCases.forEach { imageName in
            assert(ImagePalette.image(withName: imageName) != nil, "missing image: \(imageName.rawValue)")
        }
    }
}
