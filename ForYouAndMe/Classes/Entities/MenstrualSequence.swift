//
//  MenstrualSequence.swift
//  ForYouAndMe
//
//  FUAM-2933 — Originally aggregated raw menstrual diary entries into
//  "sequences" for the Compass Log (consecutive bleeding=yes collapse into a
//  single row; bleeding=no/other become their own rows).
//
//  DEPRECATED (FUAM-2934): the backend (v0.12.5) now performs this grouping
//  server-side and exposes it via `series_meta` / `series_entries`, so the
//  app no longer calls `MenstrualSequence.group(_:)`. The type is kept only
//  until a follow-up `chore` removes the file (needs a Pods.xcodeproj regen).
//

import Foundation

/// One displayable unit on the Compass Log for menstrual entries.
/// May wrap one or many `DiaryNoteItem`s sharing the same bleeding kind.
struct MenstrualSequence {
    /// Entries forming the sequence, sorted ascending by date.
    let entries: [DiaryNoteItem]
    /// Bleeding kind shared by all entries in the sequence.
    let bleeding: MenstrualBleeding

    /// Representative entry — used as the sequence anchor for day-bucketing
    /// and as the `id` lookup key. The earliest entry is chosen so the row
    /// surfaces in the day group where the bleeding sequence started.
    var representative: DiaryNoteItem {
        return entries.first ?? entries[0]
    }

    var startDate: Date { entries.first?.diaryNoteId ?? Date() }
    var endDate: Date { entries.last?.diaryNoteId ?? Date() }
    var isAggregated: Bool { entries.count > 1 }
}

extension MenstrualSequence {

    /// Group menstrual diary entries per the FUAM-2933 / PRD rules:
    /// - Consecutive bleeding=yes entries collapse into a single sequence.
    /// - bleeding=no entries split runs and emit a singleton sequence.
    /// - bleeding=other entries emit a singleton sequence but do NOT split runs.
    /// Non-menstrual or unparseable entries are dropped.
    static func group(from items: [DiaryNoteItem]) -> [MenstrualSequence] {
        let menstrualOnly = items.filter { $0.diaryNoteType == .menstrualPeriod }
        let sortedAsc = menstrualOnly.sorted { $0.diaryNoteId < $1.diaryNoteId }

        var sequences: [MenstrualSequence] = []
        var yesBuffer: [DiaryNoteItem] = []

        func flushYesBuffer() {
            guard !yesBuffer.isEmpty else { return }
            sequences.append(MenstrualSequence(entries: yesBuffer, bleeding: .yes))
            yesBuffer.removeAll()
        }

        for item in sortedAsc {
            switch bleeding(for: item) {
            case .yes:
                yesBuffer.append(item)
            case .no:
                flushYesBuffer()
                sequences.append(MenstrualSequence(entries: [item], bleeding: .no))
            case .other:
                sequences.append(MenstrualSequence(entries: [item], bleeding: .other))
            case .none:
                continue
            }
        }
        flushYesBuffer()
        return sequences
    }

    /// Extract the bleeding kind from a menstrual `DiaryNoteItem` payload.
    /// Returns nil for unparseable payloads so callers can drop the entry.
    private static func bleeding(for item: DiaryNoteItem) -> MenstrualBleeding? {
        guard case let .menstrual(_, _, _, raw, _) = item.payload else { return nil }
        return MenstrualBleeding(rawValue: raw)
    }
}
