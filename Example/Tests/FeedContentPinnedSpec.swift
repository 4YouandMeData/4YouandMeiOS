//
//  FeedContentPinnedSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2932: verifies that FeedContent.init(withFeeds:) routes feeds
//  whose notifiable is a pinned Alert into pinnedAlerts and excludes
//  them from quickActivities and feedItems.
//

import Quick
import Nimble
@testable import ForYouAndMe

class FeedContentPinnedSpec: QuickSpec {
    override class func spec() {
        describe("FeedContent pinned alerts") {

            context("when the feed contains a pinned alert and a regular alert") {
                it("separates the pinned alert into pinnedAlerts only") {
                    let pinned = makeFeed(id: "p1",
                                          alertJSON: """
                    {
                        "id": "ap1",
                        "type": "feed_alert",
                        "title": "Pinned",
                        "task_action_button_label": "Yes",
                        "secondary_button_label": "No",
                        "pinned": true
                    }
                    """)

                    let regular = makeFeed(id: "r1",
                                           alertJSON: """
                    {
                        "id": "ar1",
                        "type": "feed_alert",
                        "title": "Regular",
                        "task_action_button_label": "OK"
                    }
                    """)

                    guard let p = pinned, let r = regular else {
                        fail("Stub feeds failed to decode")
                        return
                    }

                    let content = FeedContent(withFeeds: [p, r])

                    expect(content.pinnedAlerts.count).to(equal(1))
                    expect(content.pinnedAlerts.first?.id).to(equal("p1"))
                    expect(content.feedItems.count).to(equal(1))
                    expect(content.feedItems.first?.id).to(equal("r1"))
                    expect(content.quickActivities).to(beEmpty())
                }
            }

            context("when no feed is pinned") {
                it("returns empty pinnedAlerts and routes alerts into feedItems") {
                    let regular = makeFeed(id: "r2",
                                           alertJSON: """
                    {
                        "id": "ar2",
                        "type": "feed_alert",
                        "title": "Regular",
                        "task_action_button_label": "OK",
                        "pinned": false
                    }
                    """)

                    guard let r = regular else {
                        fail("Stub feed failed to decode")
                        return
                    }

                    let content = FeedContent(withFeeds: [r])

                    expect(content.pinnedAlerts).to(beEmpty())
                    expect(content.feedItems.count).to(equal(1))
                }
            }
        }
    }
}

// MARK: - Helpers

private func makeFeed(id: String, alertJSON: String) -> Feed? {
    let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    let now = isoFormatter.string(from: Date())
    let later = isoFormatter.string(from: Date().addingTimeInterval(3600))

    let json = """
    {
        "id": "\(id)",
        "type": "feed",
        "from": "\(now)",
        "to": "\(later)",
        "notifiable": \(alertJSON)
    }
    """

    guard let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(Feed.self, from: data)
}
