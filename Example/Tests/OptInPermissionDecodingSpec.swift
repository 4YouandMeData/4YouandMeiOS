//
//  OptInPermissionDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3364: covers the two new permission-resource fields (`platforms`
//  and `agreement_display`) and the backward-compat defaults applied when
//  the BE response omits them. Exercises the model's Codable path directly
//  with a single-level JSON, matching the style of the other entity-level
//  decoding specs in this target.
//

import Quick
import Nimble
@testable import ForYouAndMe

class OptInPermissionDecodingSpec: QuickSpec {
    override class func spec() {
        // Helper: builds a minimally-valid `permission` attributes blob with
        // the caller-supplied extra fields tacked on. Keeps the per-test
        // JSON compact while ensuring every required field is present.
        func decode(extraFields: String) -> OptInPermission? {
            let json = """
            {
                "id": "221",
                "type": "permission",
                "title": "SensorKit",
                "body": "Permission senza scelta",
                "agree_text": "",
                "disagree_text": "",
                "system_permissions": [],
                "mandatory": false,
                "mandatory_description": ""\(extraFields.isEmpty ? "" : ",\n                \(extraFields)")
            }
            """.data(using: .utf8)!
            return try? JSONDecoder().decode(OptInPermission.self, from: json)
        }

        describe("OptInPermission.decode — FUAM-3364 backward compatibility") {
            it("defaults platforms to [] when the field is absent (legacy BE)") {
                let permission = decode(extraFields: "")
                expect(permission).toNot(beNil())
                expect(permission?.platforms).to(equal([]))
                expect(permission?.isAvailableOnIOS).to(beTrue())
            }

            it("defaults agreementDisplay to .agreeDisagree when absent (legacy BE)") {
                let permission = decode(extraFields: "")
                expect(permission?.agreementDisplay).to(equal(.agreeDisagree))
                expect(permission?.isInfoOnly).to(beFalse())
            }

            it("defaults platforms to [] when explicitly null") {
                let permission = decode(extraFields: "\"platforms\": null")
                expect(permission?.platforms).to(equal([]))
                expect(permission?.isAvailableOnIOS).to(beTrue())
            }

            it("defaults agreementDisplay to .agreeDisagree when explicitly null") {
                let permission = decode(extraFields: "\"agreement_display\": null")
                expect(permission?.agreementDisplay).to(equal(.agreeDisagree))
            }

            it("treats an empty platforms array as 'all platforms'") {
                let permission = decode(extraFields: "\"platforms\": []")
                expect(permission?.platforms).to(equal([]))
                expect(permission?.isAvailableOnIOS).to(beTrue())
            }
        }

        describe("OptInPermission.decode — FUAM-3364 platform gating") {
            it("renders on iOS when platforms == [\"ios\"]") {
                let permission = decode(extraFields: "\"platforms\": [\"ios\"]")
                expect(permission?.platforms).to(equal(["ios"]))
                expect(permission?.isAvailableOnIOS).to(beTrue())
            }

            it("is skipped on iOS when platforms == [\"android\"]") {
                let permission = decode(extraFields: "\"platforms\": [\"android\"]")
                expect(permission?.platforms).to(equal(["android"]))
                expect(permission?.isAvailableOnIOS).to(beFalse())
            }

            it("renders on iOS when platforms == [\"ios\", \"android\"]") {
                let permission = decode(extraFields: "\"platforms\": [\"ios\", \"android\"]")
                expect(permission?.platforms).to(equal(["ios", "android"]))
                expect(permission?.isAvailableOnIOS).to(beTrue())
            }

            it("ignores unknown platform identifiers but still gates by 'ios' membership") {
                // A future "web" entry without "ios" must still be skipped on iOS;
                // platform filtering is membership-based, not allow-list-based.
                let permission = decode(extraFields: "\"platforms\": [\"web\"]")
                expect(permission?.platforms).to(equal(["web"]))
                expect(permission?.isAvailableOnIOS).to(beFalse())
            }
        }

        describe("OptInPermission.decode — FUAM-3364 agreement_display") {
            it("decodes the literal 'agree_disagree'") {
                let permission = decode(extraFields: "\"agreement_display\": \"agree_disagree\"")
                expect(permission?.agreementDisplay).to(equal(.agreeDisagree))
                expect(permission?.isInfoOnly).to(beFalse())
            }

            it("decodes the literal 'disabled' as the info-only variant") {
                let permission = decode(extraFields: "\"agreement_display\": \"disabled\"")
                expect(permission?.agreementDisplay).to(equal(.disabled))
                expect(permission?.isInfoOnly).to(beTrue())
            }

            it("falls back to .agreeDisagree on an unrecognised value (forward-compat)") {
                // If a future BE rev introduces "info_only" / "neutral" / etc.
                // older SDK builds should render the standard screen rather
                // than crash or skip the permission.
                let permission = decode(extraFields: "\"agreement_display\": \"some_future_mode\"")
                expect(permission?.agreementDisplay).to(equal(.agreeDisagree))
                expect(permission?.isInfoOnly).to(beFalse())
            }
        }

        describe("OptInPermission.decode — full FUAM-3171 example payload") {
            it("decodes the info-only iOS-gated SensorKit permission end-to-end") {
                let permission = decode(
                    extraFields: "\"agreement_display\": \"disabled\", \"platforms\": [\"ios\"]"
                )
                expect(permission).toNot(beNil())
                expect(permission?.id).to(equal("221"))
                expect(permission?.title).to(equal("SensorKit"))
                expect(permission?.body).to(equal("Permission senza scelta"))
                expect(permission?.platforms).to(equal(["ios"]))
                expect(permission?.agreementDisplay).to(equal(.disabled))
                expect(permission?.isAvailableOnIOS).to(beTrue())
                expect(permission?.isInfoOnly).to(beTrue())
            }
        }
    }
}
