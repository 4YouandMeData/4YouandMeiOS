//
//  AlertDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2932: verifies the Alert entity decodes the new fields
//  introduced for the menstrual cycle pinned card while remaining
//  backward compatible with existing payloads.
//

import Quick
import Nimble
@testable import ForYouAndMe

class AlertDecodingSpec: QuickSpec {
    override class func spec() {
        describe("Alert decoding") {

            context("with new pinned/secondary fields") {
                it("decodes pinned and secondary_button_label when present") {
                    let json = """
                    {
                        "id": "1",
                        "type": "feed_alert",
                        "title": "Have you had a menstrual period today?",
                        "description": "Tap Yes or No.",
                        "task_action_button_label": "Yes",
                        "secondary_button_label": "No",
                        "pinned": true,
                        "card_color": "#1F4D44"
                    }
                    """.data(using: .utf8)!

                    let alert = try? JSONDecoder().decode(Alert.self, from: json)

                    expect(alert).toNot(beNil())
                    expect(alert?.pinned).to(equal(true))
                    expect(alert?.isPinned).to(beTrue())
                    expect(alert?.buttonText).to(equal("Yes"))
                    expect(alert?.secondaryButtonText).to(equal("No"))
                    expect(alert?.title).to(equal("Have you had a menstrual period today?"))
                }
            }

            context("with legacy payload (no pinned/secondary fields)") {
                it("remains backward compatible with isPinned defaulting to false") {
                    let json = """
                    {
                        "id": "42",
                        "type": "feed_alert",
                        "title": "Legacy alert",
                        "description": "Legacy body",
                        "task_action_button_label": "OK",
                        "link_url": "https://example.com"
                    }
                    """.data(using: .utf8)!

                    let alert = try? JSONDecoder().decode(Alert.self, from: json)

                    expect(alert).toNot(beNil())
                    expect(alert?.pinned).to(beNil())
                    expect(alert?.isPinned).to(beFalse())
                    expect(alert?.secondaryButtonText).to(beNil())
                    expect(alert?.buttonText).to(equal("OK"))
                    expect(alert?.urlString).to(equal("https://example.com"))
                }
            }

            context("with empty secondary_button_label") {
                it("treats empty string as nil via NilIfEmptyString") {
                    let json = """
                    {
                        "id": "7",
                        "type": "feed_alert",
                        "title": "Title",
                        "task_action_button_label": "Yes",
                        "secondary_button_label": "",
                        "pinned": false
                    }
                    """.data(using: .utf8)!

                    let alert = try? JSONDecoder().decode(Alert.self, from: json)

                    expect(alert).toNot(beNil())
                    expect(alert?.secondaryButtonText).to(beNil())
                    expect(alert?.isPinned).to(beFalse())
                }
            }
        }
    }
}
