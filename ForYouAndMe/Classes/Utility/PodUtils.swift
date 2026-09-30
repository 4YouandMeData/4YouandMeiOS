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
        // Under the test host (ForYouAndMe_Tests.xctest) the framework is double-loaded, so
        // `Bundle(for: PodUtils.self)` resolves to the xctest bundle rather than the
        // framework's own bundle, and that bundle has no nested resource bundle to find.
        // Fall back to the main bundle, which — in both the test host and any real app — is
        // where the pod resource bundle actually gets copied. Only trip the assertion below
        // when neither lookup finds it.
        guard let podResourceBundleUrl = Bundle(for: PodUtils.self).url(forResource: name, withExtension: "bundle")
            ?? Bundle.main.url(forResource: name, withExtension: "bundle") else {
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
