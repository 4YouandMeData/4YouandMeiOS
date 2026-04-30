//
//  DiaryNoteMenstrualStub.swift
//  ForYouAndMe
//
//  DEBUG-only helper for FUAM-2933 to seed the Compass Log with menstrual
//  diary entries that exercise the grouping rules (yes-run, isolated no,
//  isolated other). Remove or set `isEnabled = false` once the backend
//  serves real menstrual entries on the dev environment.
//

import Foundation

#if DEBUG

enum DiaryNoteMenstrualStub {

    /// Toggle to enable/disable stub injection at runtime without rebuilding.
    static var isEnabled: Bool = true

    /// Build the synthetic menstrual entries used to verify FUAM-2933.
    /// Layout exercises every grouping branch:
    ///  - 3-day yes-run starting 5 days ago (collapses into one Compass Log row)
    ///  - isolated `no` 1 day ago (singleton row, splits yes runs)
    ///  - isolated `other` today (singleton row, does NOT split runs)
    static func entries() -> [DiaryNoteItem] {
        let calendar = Calendar.current
        let now = Date()

        func daysAgo(_ days: Int) -> Date {
            return calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }

        func makeMenstrualEntry(id: String,
                                date: Date,
                                bleeding: String,
                                periodRelated: String,
                                flowAmount: String,
                                note: String?,
                                emoji: EmojiItem? = nil) -> DiaryNoteItem {
            var item = DiaryNoteItem(
                id: id,
                type: "diary_note",
                diaryNoteId: date,
                diaryNoteType: .menstrualPeriod,
                title: nil,
                body: nil,
                interval: nil
            )
            item.payload = .menstrual(
                date: date,
                flowAmount: flowAmount,
                periodRelated: periodRelated,
                bleeding: bleeding,
                note: note
            )
            if let emoji = emoji {
                item.feedbackTags = [emoji]
            }
            return item
        }

        func emoji(id: String, tag: String, label: String) -> EmojiItem {
            // EmojiItem JSON-codes from a `{id, type, tag, label}` dict; the
            // synchronous decoder accepts a small inline JSON blob so we don't
            // need a custom in-app initializer.
            let json: [String: Any] = [
                "id": id,
                "type": "feedback_tag",
                "tag": tag,
                "label": label
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: json),
                  let item = try? JSONDecoder().decode(EmojiItem.self, from: data) else {
                fatalError("Failed to build stub EmojiItem")
            }
            return item
        }

        // Reusable emoji samples covering the typical menstrual reactions.
        let scaredEmoji = emoji(id: "stub_emoji_scared", tag: "😱", label: "scared")
        let painEmoji = emoji(id: "stub_emoji_pain", tag: "😣", label: "in_pain")
        let calmEmoji = emoji(id: "stub_emoji_calm", tag: "😌", label: "calm")

        var stubs: [DiaryNoteItem] = []

        // 3-day yes-run (5 → 3 days ago) — should collapse into a single row.
        let yesRunEmojis: [EmojiItem?] = [calmEmoji, painEmoji, nil]
        for (index, daysOffset) in [5, 4, 3].enumerated() {
            let date = daysAgo(daysOffset)
            stubs.append(makeMenstrualEntry(
                id: "stub_menstrual_yes_\(index)",
                date: date,
                bleeding: "yes",
                periodRelated: "yes",
                flowAmount: index == 0 ? "light" : (index == 1 ? "moderate" : "heavy"),
                note: index == 1 ? "Cramps in the afternoon" : nil,
                emoji: yesRunEmojis[index]
            ))
        }

        // Isolated `no` (1 day ago) — singleton row, splits yes runs.
        stubs.append(makeMenstrualEntry(
            id: "stub_menstrual_no",
            date: daysAgo(1),
            bleeding: "no",
            periodRelated: "no",
            flowAmount: "spotting",
            note: "Spotting after a long run",
            emoji: nil
        ))

        // Isolated `other` (today) — singleton row, does NOT split runs.
        stubs.append(makeMenstrualEntry(
            id: "stub_menstrual_other",
            date: now,
            bleeding: "other",
            periodRelated: "let_me_explain",
            flowAmount: "light",
            note: "After IUD insertion",
            emoji: scaredEmoji
        ))

        return stubs
    }

    /// Inject stub entries when enabled. Idempotent — guards against
    /// duplicating stubs when the diary list reloads multiple times.
    static func inject(into items: [DiaryNoteItem]) -> [DiaryNoteItem] {
        guard isEnabled else { return items }
        let stubIds = Set(entries().map { $0.id })
        if items.contains(where: { stubIds.contains($0.id) }) {
            return items
        }
        return items + entries()
    }
}

#endif
