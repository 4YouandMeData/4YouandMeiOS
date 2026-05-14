//
//  MenstrualSequenceGroupingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2933: verifies the bleeding-aware grouping algorithm that turns
//  raw menstrual diary entries into Compass Log sequences:
//  - consecutive yes → one sequence
//  - no → singleton, splits yes runs
//  - other → singleton, does NOT split yes runs
//

import Quick
import Nimble
@testable import ForYouAndMe

class MenstrualSequenceGroupingSpec: QuickSpec {
    override class func spec() {
        describe("MenstrualSequence.group") {

            func makeEntry(id: String, date: Date, bleeding: String) -> DiaryNoteItem {
                var item = DiaryNoteItem(diaryNoteId: nil, body: nil, interval: nil, diaryNoteable: nil)
                item.diaryNoteType = .menstrualPeriod
                // Re-init through the canonical constructor to fix id/date.
                let template = DiaryNoteItem(
                    id: id,
                    type: "diary_note",
                    diaryNoteId: date,
                    diaryNoteType: .menstrualPeriod,
                    title: nil,
                    body: nil,
                    interval: nil
                )
                item = template
                item.payload = .menstrual(date: date,
                                          flowAmount: "moderate",
                                          periodRelated: "yes",
                                          bleeding: bleeding,
                                          note: nil)
                return item
            }

            let day1 = Date(timeIntervalSince1970: 1_700_000_000)
            let day2 = Date(timeIntervalSince1970: 1_700_086_400)
            let day3 = Date(timeIntervalSince1970: 1_700_172_800)
            let day4 = Date(timeIntervalSince1970: 1_700_259_200)
            let day5 = Date(timeIntervalSince1970: 1_700_345_600)

            it("collapses consecutive yes entries into one sequence") {
                let entries = [
                    makeEntry(id: "1", date: day1, bleeding: "yes"),
                    makeEntry(id: "2", date: day2, bleeding: "yes"),
                    makeEntry(id: "3", date: day3, bleeding: "yes")
                ]
                let sequences = MenstrualSequence.group(from: entries)
                expect(sequences.count).to(equal(1))
                expect(sequences[0].entries.count).to(equal(3))
                expect(sequences[0].bleeding).to(equal(.yes))
                expect(sequences[0].startDate).to(equal(day1))
                expect(sequences[0].endDate).to(equal(day3))
            }

            it("splits yes runs on a no entry") {
                let entries = [
                    makeEntry(id: "1", date: day1, bleeding: "yes"),
                    makeEntry(id: "2", date: day2, bleeding: "yes"),
                    makeEntry(id: "3", date: day3, bleeding: "no"),
                    makeEntry(id: "4", date: day4, bleeding: "yes")
                ]
                let sequences = MenstrualSequence.group(from: entries)
                expect(sequences.count).to(equal(3))
                expect(sequences[0].bleeding).to(equal(.yes))
                expect(sequences[0].entries.count).to(equal(2))
                expect(sequences[1].bleeding).to(equal(.no))
                expect(sequences[1].entries.count).to(equal(1))
                expect(sequences[2].bleeding).to(equal(.yes))
                expect(sequences[2].entries.count).to(equal(1))
            }

            it("does NOT split yes runs on an other entry") {
                let entries = [
                    makeEntry(id: "1", date: day1, bleeding: "yes"),
                    makeEntry(id: "2", date: day2, bleeding: "other"),
                    makeEntry(id: "3", date: day3, bleeding: "yes")
                ]
                let sequences = MenstrualSequence.group(from: entries)
                expect(sequences.count).to(equal(2))
                let yesSeq = sequences.first { $0.bleeding == .yes }
                expect(yesSeq?.entries.count).to(equal(2))
                let otherSeq = sequences.first { $0.bleeding == .other }
                expect(otherSeq?.entries.count).to(equal(1))
            }

            it("sorts entries ascending before grouping") {
                let entries = [
                    makeEntry(id: "3", date: day3, bleeding: "yes"),
                    makeEntry(id: "1", date: day1, bleeding: "yes"),
                    makeEntry(id: "2", date: day2, bleeding: "yes")
                ]
                let sequences = MenstrualSequence.group(from: entries)
                expect(sequences.count).to(equal(1))
                expect(sequences[0].entries.map { $0.id }).to(equal(["1", "2", "3"]))
            }

            it("uses the earliest entry as representative") {
                let entries = [
                    makeEntry(id: "1", date: day1, bleeding: "yes"),
                    makeEntry(id: "2", date: day2, bleeding: "yes")
                ]
                let sequences = MenstrualSequence.group(from: entries)
                expect(sequences[0].representative.id).to(equal("1"))
            }

            it("drops non-menstrual entries") {
                var nonMenstrual = DiaryNoteItem(
                    id: "x",
                    type: "diary_note",
                    diaryNoteId: day1,
                    diaryNoteType: .text,
                    title: nil,
                    body: nil,
                    interval: nil
                )
                nonMenstrual.payload = nil
                let entries = [
                    nonMenstrual,
                    makeEntry(id: "1", date: day2, bleeding: "yes")
                ]
                let sequences = MenstrualSequence.group(from: entries)
                expect(sequences.count).to(equal(1))
                expect(sequences[0].entries.first?.id).to(equal("1"))
            }

            it("handles a complex mix: yes, yes, other, yes, no, yes") {
                let entries = [
                    makeEntry(id: "1", date: day1, bleeding: "yes"),
                    makeEntry(id: "2", date: day2, bleeding: "yes"),
                    makeEntry(id: "3", date: day3, bleeding: "other"),
                    makeEntry(id: "4", date: day4, bleeding: "no"),
                    makeEntry(id: "5", date: day5, bleeding: "yes")
                ]
                let sequences = MenstrualSequence.group(from: entries)
                expect(sequences.count).to(equal(4))
                // Walk emits: other (d3) is emitted immediately on encounter (does
                // not flush), then no (d4) flushes the yes buffer (d1+d2) before
                // emitting itself, then yes (d5) is buffered and flushed at end.
                expect(sequences[0].bleeding).to(equal(.other))
                let yesRun = sequences.first {
                    $0.bleeding == .yes && $0.entries.count == 2
                }
                expect(yesRun?.entries.map { $0.id }).to(equal(["1", "2"]))
                expect(sequences.contains { $0.bleeding == .no }).to(beTrue())
                let yesSingle = sequences.first {
                    $0.bleeding == .yes && $0.entries.count == 1
                }
                expect(yesSingle?.entries.first?.id).to(equal("5"))
            }
        }
    }
}
