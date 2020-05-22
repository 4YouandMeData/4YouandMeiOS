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
    case nextButtonPrimary
    case nextButtonSecondary
    case backButton
    case closeButton
    case checkmark
    case edit
    case checkboxOutline
    case checkboxFilled
}

public class ImagePalette {
    
    static func image(withName name: ImageName) -> UIImage? {
        if let image = UIImage(named: name.rawValue) {
            return image
        } else if let podBundle = PodUtils.getPodResourceBundle(withName: Constants.Resources.DefaultBundleName) {
            return UIImage(named: name.rawValue, in: podBundle, with: nil)
        } else {
            return nil
        }
    }
    
    static func checkImageAvailability() {
        ImageName.allCases.forEach { imageName in
            assert(ImagePalette.image(withName: imageName) != nil, "missing image: \(imageName.rawValue)")
        }
    }
}
