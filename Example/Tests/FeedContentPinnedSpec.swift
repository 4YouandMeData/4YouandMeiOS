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

                    let content = FeedContent(withFeeds: [p, r], kpiState: .idle)

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

                    let content = FeedContent(withFeeds: [r], kpiState: .idle)

                    expect(content.pinnedAlerts).to(beEmpty())
                    expect(content.feedItems.count).to(equal(1))
                }
            }
        }

        // FUAM-4315 (D3, D13, D16): KPI widgets sit between pinned alerts and quick activities,
        // survive page merges, and an empty feed with a widget shows the widget then the empty text.
        describe("FeedContent KPI widget section") {
            let widget = KpiWidget(id: "1", type: "kpi_widget", kpiType: "quick_activities_adherence",
                                   displayMode: "gauge", position: 1, featured: false, completed: 5, total: 6,
                                   percentage: 83.33, meetsThreshold: true, title: "T", body: nil)

            it("orders pinned alerts, KPI widgets, quick activities, dated sections") {
                guard let pinned = makePinnedFeed(id: "p"), let regular = makeRegularFeed(id: "r"),
                      let quickActivity = makeQuickActivityFeed(id: "q") else {
                    fail("Stub feeds failed to decode")
                    return
                }
                var content = FeedContent(withFeeds: [regular, quickActivity, pinned], kpiState: .loaded([widget]))
                expect(sectionNames(&content)).to(equal(["PinnedAlertSection", "KpiWidgetSection",
                                                         "QuickActivitySection", "FeedSection"]))
                expect(content.sections[1].numberOfRows).to(equal(1))
                expect(content.sections[1].sectionText).to(beNil())
                // Widgets are not feed items: pagination is unaffected.
                expect(content.itemCount).to(equal(4))
            }

            it("adds no section for an empty or idle KPI state") {
                guard let quickActivity = makeQuickActivityFeed(id: "q") else {
                    fail("Stub feed failed to decode")
                    return
                }
                var loadedEmpty = FeedContent(withFeeds: [quickActivity], kpiState: .loaded([]))
                var idle = FeedContent(withFeeds: [quickActivity], kpiState: .idle)
                expect(sectionNames(&loadedEmpty)).to(equal(["QuickActivitySection"]))
                expect(sectionNames(&idle)).to(equal(["QuickActivitySection"]))
            }

            it("keeps the KPI state when a page is appended") {
                guard let first = makeRegularFeed(id: "r1"), let second = makeRegularFeed(id: "r2") else {
                    fail("Stub feeds failed to decode")
                    return
                }
                let current: FeedContent? = FeedContent(withFeeds: [first], kpiState: .loaded([widget]))
                var merged = current.merge(withContent: FeedContent(withFeeds: [second], kpiState: .loaded([widget])))
                expect(merged.kpiState).to(equal(.loaded([widget])))
                expect(merged.feedItems.map { $0.id }).to(equal(["r1", "r2"]))
                expect(sectionNames(&merged).first).to(equal("KpiWidgetSection"))
            }

            it("rebuilds the sections when the KPI state changes") {
                guard let regular = makeRegularFeed(id: "r") else {
                    fail("Stub feed failed to decode")
                    return
                }
                var idle = FeedContent(withFeeds: [regular], kpiState: .idle)
                expect(sectionNames(&idle)).to(equal(["FeedSection"]))
                var loaded = idle.with(kpiState: .loaded([widget]))
                expect(sectionNames(&loaded)).to(equal(["KpiWidgetSection", "FeedSection"]))
            }

            it("shows the widget then the empty-feed row when the feed is empty") {
                var withWidget = FeedContent(withFeeds: [], kpiState: .loaded([widget]))
                expect(sectionNames(&withWidget)).to(equal(["KpiWidgetSection", "EmptyFeedSection"]))
                expect(withWidget.sections[1].numberOfRows).to(equal(1))
                // No widget: no sections, so the background FeedEmptyView keeps today's behaviour.
                var withoutWidget = FeedContent(withFeeds: [], kpiState: .loaded([]))
                expect(withoutWidget.sections).to(beEmpty())
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

private func sectionNames(_ content: inout FeedContent) -> [String] {
    return content.sections.map { String(describing: type(of: $0)) }
}

private func makePinnedFeed(id: String) -> Feed? {
    return makeFeed(id: id, alertJSON: """
    { "id": "a\(id)", "type": "feed_alert", "title": "Pinned", "task_action_button_label": "Yes", "pinned": true }
    """)
}

private func makeRegularFeed(id: String) -> Feed? {
    return makeFeed(id: id, alertJSON: """
    { "id": "a\(id)", "type": "feed_alert", "title": "Regular", "task_action_button_label": "OK" }
    """)
}

private func makeQuickActivityFeed(id: String) -> Feed? {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let json = """
    {
        "id": "\(id)",
        "type": "feed",
        "from": "\(isoFormatter.string(from: Date()))",
        "to": "\(isoFormatter.string(from: Date().addingTimeInterval(3600)))",
        "schedulable": { "id": "qa_\(id)", "type": "quick_activity", "quick_activity_options": [] }
    }
    """
    return try? JSONDecoder().decode(Feed.self, from: Data(json.utf8))
}
