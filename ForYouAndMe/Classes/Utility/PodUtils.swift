//
//  PodUtils.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//

import Foundation

class PodUtils {
    static let podDefaultResourceBundle: Bundle = Bundle(url: Bundle(for: PodUtils.self)
        .url(forResource: "ForYouAndMe", withExtension: "bundle")!)!
}
