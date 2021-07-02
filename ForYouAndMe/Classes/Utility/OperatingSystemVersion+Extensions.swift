//
//  OperatingSystemVersion+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/21.
//

import Foundation

extension OperatingSystemVersion {
    var stringValue: String {
        return "\(self.majorVersion).\(self.minorVersion).\(self.patchVersion)"
    }
}
