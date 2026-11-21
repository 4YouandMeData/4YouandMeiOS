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
        describe("values decoded from a real plist") {
            let cases: [(String, Bool)] = [
                ("<true/>", true), ("<false/>", false), ("<integer>2</integer>", true),
                ("<integer>0</integer>", false), ("<string>NO</string>", false), ("<string></string>", true)
            ]
            for (xml, expected) in cases {
                it("maps \(xml) to \(expected)") {
                    let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>k</key>\(xml)</dict></plist>"
                    let decoded = try? PropertyListSerialization.propertyList(from: Data(plist.utf8), options: [], format: nil)
                    let dict = decoded as? [String: Any]
                    // A decode failure would yield nil, which also maps to true: require a real value.
                    expect(dict?["k"]).toNot(beNil())
                    expect(HostAppConfig.darkModeAllowed(fromInfoValue: dict?["k"])) == expected
                }
            }
        }
    }
}
