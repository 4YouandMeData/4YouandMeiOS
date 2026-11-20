//
//  HostAppConfigDarkModeSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4413: parsing of the FYAMDarkModeAllowed Info.plist value (assertion branches not covered).
//

import Quick
import Nimble
@testable import ForYouAndMe

class HostAppConfigDarkModeSpec: QuickSpec {
    override class func spec() {
        describe("HostAppConfig.darkModeAllowed(fromInfoValue:)") {
            let cases: [(String, Any?, Bool)] = [
                ("nil", nil, true), ("true", true, true), ("false", false, false),
                ("NSNumber 1", NSNumber(value: 1), true), ("NSNumber 0", NSNumber(value: 0), false),
                ("YES", "YES", true), ("no", "no", false), (" True ", " True ", true),
                ("1", "1", true), ("0", "0", false),
                ("empty", "", true), ("unresolved", "$(FYAM_DARK_MODE_ALLOWED)", true)
            ]
            for (name, input, expected) in cases {
                it("maps \(name) to \(expected)") {
                    expect(HostAppConfig.darkModeAllowed(fromInfoValue: input)) == expected
                }
            }
        }
    }
}
