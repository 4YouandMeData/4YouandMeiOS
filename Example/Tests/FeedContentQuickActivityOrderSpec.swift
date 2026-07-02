//
//  FeedContentQuickActivityOrderSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3398: verifies that FeedContent.init(withFeeds:) applies a per-page
//  STABLE sort of quick activities by `metadata.order` (ascending). Items
//  with no `order` go last; equal-order ties and the null block must preserve
//  the original (server) order.
//

import Quick
import Nimble
@testable import ForYouAndMe

class FeedContentQuickActivityOrderSpec: QuickSpec {
    override class func spec() {
        describe("FeedContent quick activity ordering (FUAM-3398)") {

            context("with mixed order values, ties, and items without metadata") {
                it("sorts ascending, places nulls last, and keeps ties and the null block stable") {
                    // Server order (as received): the `order` and `id` are chosen so that a
                    // correct stable sort produces a deterministic, distinguishable result.
                    //
                    //  server idx | id   | order
                    //  -----------+------+-------
                    //      0      | a    | 2
                    //      1      | b    | nil   (no metadata at all)
                    //      2      | c    | 1
                    //      3      | d    | 2     (tie with `a` -> must stay after `a`)
                    //      4      | e    | nil   ({} empty metadata, order absent)
                    //      5      | f    | 1     (tie with `c` -> must stay after `c`)
                    //
                    // Expected after stable ascending sort, nulls last:
                    //   c (1), f (1), a (2), d (2), b (nil), e (nil)
                    let feeds: [Feed] = [
                        makeQuickActivityFeed(id: "a", metadataJSON: #"{"order": 2}"#),
                        makeQuickActivityFeed(id: "b", metadataJSON: nil),
                        makeQuickActivityFeed(id: "c", metadataJSON: #"{"order": 1}"#),
                        makeQuickActivityFeed(id: "d", metadataJSON: #"{"order": 2}"#),
                        makeQuickActivityFeed(id: "e", metadataJSON: "{}"),
                        makeQuickActivityFeed(id: "f", metadataJSON: #"{"order": 1}"#)
                    ].compactMap { $0 }

                    expect(feeds.count).to(equal(6), description: "all stub quick activities should decode")

                    let content = FeedContent(withFeeds: feeds)

                    let resultIds = content.quickActivities.map { $0.id }
                    expect(resultIds).to(equal(["c", "f", "a", "d", "b", "e"]))
                }
            }

            context("when no quick activity carries an order") {
                it("preserves the original server order") {
                    let feeds: [Feed] = [
                        makeQuickActivityFeed(id: "x", metadataJSON: nil),
                        makeQuickActivityFeed(id: "y", metadataJSON: "{}"),
                        makeQuickActivityFeed(id: "z", metadataJSON: nil)
                    ].compactMap { $0 }

                    expect(feeds.count).to(equal(3))

                    let content = FeedContent(withFeeds: feeds)

                    expect(content.quickActivities.map { $0.id }).to(equal(["x", "y", "z"]))
                }
            }
        }
    }
}

// MARK: - Helpers

private func makeQuickActivityFeed(id: String, metadataJSON: String?) -> Feed? {
    let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    let now = isoFormatter.string(from: Date())
    let later = isoFormatter.string(from: Date().addingTimeInterval(3600))

    let metadataLine = metadataJSON.map { ",\n        \"metadata\": \($0)" } ?? ""

    let json = """
    {
        "id": "\(id)",
        "type": "feed",
        "from": "\(now)",
        "to": "\(later)",
        "schedulable": {
            "id": "qa_\(id)",
            "type": "quick_activity",
            "quick_activity_options": []
        }\(metadataLine)
    }
    """

    guard let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(Feed.self, from: data)
}
