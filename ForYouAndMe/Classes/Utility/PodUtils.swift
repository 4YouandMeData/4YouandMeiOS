//
//  PodUtils.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

class PodUtils {
    static func getPodResourceBundle(withName name: String) -> Bundle? {
        guard let podResourceBundleUrl = Bundle(for: PodUtils.self).url(forResource: name, withExtension: "bundle") else {
            assertionFailure("Missing Pod Resource Bundle URL")
            return nil
        }
        guard let podResourceBundle = Bundle(url: podResourceBundleUrl) else {
            assertionFailure("Missing Pod Resource Bundle")
            return nil
        }
        return podResourceBundle
    }
}
