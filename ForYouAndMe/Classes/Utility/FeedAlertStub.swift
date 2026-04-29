//
//  FeedAlertStub.swift
//  ForYouAndMe
//
//  DEBUG-only helper for FUAM-2932 to inject a synthetic pinned FeedAlert into
//  the feed while the backend is not yet emitting menstrual cycle alerts.
//  Remove once the trigger is live on the dev environment.
//

import Foundation

#if DEBUG

enum FeedAlertStub {

    /// Toggle to enable/disable stub injection at runtime without rebuilding.
    static var isEnabled: Bool = true

    /// Returns a synthetic pinned menstrual feed alert, or nil if decoding fails.
    static func menstrualPinnedFeed() -> Feed? {
        let isoFormatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()

        let now = isoFormatter.string(from: Date())
        let tomorrow = isoFormatter.string(from: Date().addingTimeInterval(60 * 60 * 24))

        let json: [String: Any] = [
            "id": "stub_menstrual_pinned_001",
            "type": "feed",
            "from": now,
            "to": tomorrow,
            "notifiable": [
                "id": "stub_alert_menstrual_001",
                "type": "feed_alert",
                "title": "Have you had a menstrual period today or recently?",
                "description": "Tracking your cycle helps us understand your study patterns over time.",
                "task_action_button_label": "Yes",
                "secondary_button_label": "No",
                "pinned": true,
                "card_color": "#1F4D44"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        return try? JSONDecoder().decode(Feed.self, from: data)
    }

    /// Inject the stub into the feed list when enabled. Idempotent: avoids
    /// duplicating the stub if it is already present in the input.
    static func inject(into feeds: [Feed]) -> [Feed] {
        guard isEnabled else { return feeds }
        guard feeds.contains(where: { $0.id == "stub_menstrual_pinned_001" }) == false else {
            return feeds
        }
        guard let stub = menstrualPinnedFeed() else { return feeds }
        return [stub] + feeds
    }
}

#endif
