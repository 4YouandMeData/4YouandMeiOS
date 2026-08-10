//
//  EnrollmentBackfillWindowingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3841: enrollment-bounded backfill — pure-logic specs for the consent boundary.
//
//  Under test (all static, no HealthKit/SensorKit runtime needed):
//  - RepositoryImpl.enrollmentDate(fromDaysInStudy:now:calendar:)
//      backend semantics: days_in_study is 1 ON the enrollment day
//      ((end_date - onboarding_date).to_i + 1), <= 0 is not a valid enrolled state.
//  - SensorSampleUploadManager.buildWindowPlan(...)
//      first window never opens before the enrollment/retention lower bound; upper
//      bound honours the 24h embargo (day-aligned for report sensors); empty plan
//      when the bound has already reached the safe upper bound.
//  - SensorSampleUploadManager.dropPreEnrollmentRecords(_:enrollmentDate:windowStart:)
//      hard consent gate across the heterogeneous timestamp keys; records without a
//      parseable timestamp are kept only when the whole window is >= enrollment.
//  - SensorSampleUploadManager.splitRespectingPayloadLimit(_:maxBatchSize:maxBatchBytes:)
//      bisection terminates on a single oversized record and preserves order.
//

import Quick
import Nimble
@testable import ForYouAndMe

class EnrollmentBackfillWindowingSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let calendar = utcCalendar

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let embargo: TimeInterval = day
        let retentionFloor: TimeInterval = 7 * day

        // 2026-08-10 12:00:00 UTC
        let now = Date(timeIntervalSince1970: 1786104000)
        let startOfToday = calendar.startOfDay(for: now)

        func iso(_ date: Date) -> String {
            return ISO8601DateFormatter().string(from: date)
        }

        describe("RepositoryImpl.enrollmentDate(fromDaysInStudy:)") {

            it("maps day-of-enrollment (days_in_study == 1) to startOfDay(today)") {
                let result = RepositoryImpl.enrollmentDate(fromDaysInStudy: 1, now: now, calendar: calendar)
                expect(result).to(equal(startOfToday))
            }

            it("maps days_in_study == 2 to startOfDay(yesterday)") {
                let result = RepositoryImpl.enrollmentDate(fromDaysInStudy: 2, now: now, calendar: calendar)
                expect(result).to(equal(calendar.date(byAdding: .day, value: -1, to: startOfToday)))
            }

            it("returns nil for days_in_study == 0") {
                expect(RepositoryImpl.enrollmentDate(fromDaysInStudy: 0, now: now, calendar: calendar)).to(beNil())
            }

            it("returns nil for negative days_in_study") {
                expect(RepositoryImpl.enrollmentDate(fromDaysInStudy: -3, now: now, calendar: calendar)).to(beNil())
            }
        }

        describe("SensorSampleUploadManager.buildWindowPlan") {

            func plan(dayAggregated: Bool, enrollment: Date?, cursor: Date?) -> SensorSampleUploadManager.WindowPlan {
                return SensorSampleUploadManager.buildWindowPlan(dayAggregated: dayAggregated,
                                                                 now: now,
                                                                 enrollmentDate: enrollment,
                                                                 cursor: cursor,
                                                                 retentionFloor: retentionFloor,
                                                                 embargo: embargo,
                                                                 calendar: calendar)
            }

            context("continuous sensor") {

                it("opens at the retention floor when there is no enrollment date nor cursor") {
                    let result = plan(dayAggregated: false, enrollment: nil, cursor: nil)
                    expect(result.lowerBoundOrigin).to(equal("retention_floor"))
                    expect(result.windows.first?.start).to(equal(now.addingTimeInterval(-retentionFloor)))
                }

                it("never opens before the enrollment date") {
                    let enrollment = now.addingTimeInterval(-3 * day)
                    let result = plan(dayAggregated: false, enrollment: enrollment, cursor: nil)
                    expect(result.lowerBoundOrigin).to(equal("enrollment"))
                    expect(result.windows.first?.start).to(equal(enrollment))
                }

                it("never ends past the 24h embargo cutoff") {
                    let result = plan(dayAggregated: false, enrollment: nil, cursor: nil)
                    expect(result.windows.last?.end).to(equal(now.addingTimeInterval(-embargo)))
                    for window in result.windows {
                        expect(window.end.timeIntervalSince(now)).to(beLessThanOrEqualTo(-embargo))
                    }
                }

                it("resumes from a cursor ahead of the lower bound") {
                    let cursor = now.addingTimeInterval(-2 * day)
                    let result = plan(dayAggregated: false, enrollment: nil, cursor: cursor)
                    expect(result.lowerBoundOrigin).to(equal("cursor"))
                    expect(result.windows.first?.start).to(equal(cursor))
                }

                it("ignores a stale cursor behind the lower bound") {
                    let enrollment = now.addingTimeInterval(-3 * day)
                    let cursor = now.addingTimeInterval(-6 * day)
                    let result = plan(dayAggregated: false, enrollment: enrollment, cursor: cursor)
                    expect(result.lowerBoundOrigin).to(equal("enrollment"))
                    expect(result.windows.first?.start).to(equal(enrollment))
                }

                it("returns an empty plan when the bound has reached the embargo cutoff") {
                    let enrollment = now.addingTimeInterval(-hour)
                    let result = plan(dayAggregated: false, enrollment: enrollment, cursor: nil)
                    expect(result.windows).to(beEmpty())
                }
            }

            context("day-aggregated (report) sensor") {

                it("never opens the first day-aligned window before a mid-day enrollment date") {
                    // Review fix #2: startOfDay(from) used to rewind below the enrollment bound.
                    let enrollment = now.addingTimeInterval(-3 * day).addingTimeInterval(3.5 * hour)
                    let result = plan(dayAggregated: true, enrollment: enrollment, cursor: nil)
                    expect(result.windows.first?.start).to(equal(enrollment))
                    for window in result.windows {
                        expect(window.start.timeIntervalSince(enrollment)).to(beGreaterThanOrEqualTo(0))
                    }
                }

                it("day-aligns the resume point of a mid-day cursor without passing the lower bound") {
                    let cursor = now.addingTimeInterval(-2 * day).addingTimeInterval(5 * hour)
                    let result = plan(dayAggregated: true, enrollment: nil, cursor: cursor)
                    let lowerBound = now.addingTimeInterval(-retentionFloor)
                    expect(result.windows.first?.start).to(equal(max(calendar.startOfDay(for: cursor), lowerBound)))
                }

                it("ends on a day boundary at most 24h in the past (review fix #11)") {
                    let result = plan(dayAggregated: true, enrollment: nil, cursor: nil)
                    let expectedSafeTo = calendar.startOfDay(for: now.addingTimeInterval(-embargo))
                    expect(result.windows.last?.end).to(equal(expectedSafeTo))
                    for window in result.windows.dropFirst() {
                        expect(window.start).to(equal(calendar.startOfDay(for: window.start)))
                    }
                }

                it("returns an empty plan when enrolled today (bound >= safeTo)") {
                    let result = plan(dayAggregated: true, enrollment: startOfToday, cursor: nil)
                    expect(result.windows).to(beEmpty())
                }
            }

            it("produces contiguous windows (no gaps, no overlaps)") {
                let enrollment = now.addingTimeInterval(-5 * day)
                for dayAggregated in [true, false] {
                    let result = plan(dayAggregated: dayAggregated, enrollment: enrollment, cursor: nil)
                    for (previous, next) in zip(result.windows, result.windows.dropFirst()) {
                        expect(previous.end).to(equal(next.start))
                    }
                }
            }
        }

        describe("SensorSampleUploadManager.dropPreEnrollmentRecords") {

            let enrollment = now.addingTimeInterval(-3 * day)
            let before = enrollment.addingTimeInterval(-hour)
            let after = enrollment.addingTimeInterval(hour)
            let postEnrollmentWindowStart = enrollment
            let preEnrollmentWindowStart = calendar.startOfDay(for: enrollment)

            func drop(_ records: [[String: Any]], windowStart: Date) -> [[String: Any]] {
                return SensorSampleUploadManager.dropPreEnrollmentRecords(records,
                                                                          enrollmentDate: enrollment,
                                                                          windowStart: windowStart)
            }

            it("drops a pre-enrollment record keyed by 't'") {
                let result = drop([["t": iso(before)], ["t": iso(after)]], windowStart: postEnrollmentWindowStart)
                expect(result.count).to(equal(1))
                expect(result.first?["t"] as? String).to(equal(iso(after)))
            }

            it("drops a pre-enrollment record keyed by 'start'") {
                let result = drop([["start": iso(before)]], windowStart: postEnrollmentWindowStart)
                expect(result).to(beEmpty())
            }

            it("drops a pre-enrollment record keyed by 'start_ms'") {
                let beforeMs = Int(before.timeIntervalSince1970 * 1000)
                let result = drop([["start_ms": beforeMs]], windowStart: postEnrollmentWindowStart)
                expect(result).to(beEmpty())
            }

            it("drops a pre-enrollment record keyed by 'recorded_at'") {
                let result = drop([["recorded_at": iso(before)]], windowStart: postEnrollmentWindowStart)
                expect(result).to(beEmpty())
            }

            it("drops an unparseable record when the window opens before enrollment (review fix #2)") {
                let result = drop([["payload": "opaque"]], windowStart: preEnrollmentWindowStart)
                expect(result).to(beEmpty())
            }

            it("keeps an unparseable record when the whole window is at or after enrollment") {
                let result = drop([["payload": "opaque"]], windowStart: postEnrollmentWindowStart)
                expect(result.count).to(equal(1))
            }

            it("keeps everything when there is no enrollment date") {
                let records: [[String: Any]] = [["t": iso(before)], ["payload": "opaque"]]
                let result = SensorSampleUploadManager.dropPreEnrollmentRecords(records,
                                                                                enrollmentDate: nil,
                                                                                windowStart: preEnrollmentWindowStart)
                expect(result.count).to(equal(2))
            }
        }

        describe("SensorSampleUploadManager.splitRespectingPayloadLimit") {

            it("terminates on a single oversized record and returns it alone") {
                let oversized: [String: Any] = ["blob": String(repeating: "x", count: 1024)]
                let batches = SensorSampleUploadManager.splitRespectingPayloadLimit([oversized],
                                                                                    maxBatchSize: 500,
                                                                                    maxBatchBytes: 10)
                expect(batches.count).to(equal(1))
                expect(batches.first?.count).to(equal(1))
            }

            it("bisects oversized batches down to single records, preserving order") {
                let records: [[String: Any]] = (0..<5).map { ["i": $0, "blob": String(repeating: "x", count: 64)] }
                let batches = SensorSampleUploadManager.splitRespectingPayloadLimit(records,
                                                                                    maxBatchSize: 500,
                                                                                    maxBatchBytes: 10)
                let flattened = batches.flatMap { $0 }.compactMap { $0["i"] as? Int }
                expect(flattened).to(equal([0, 1, 2, 3, 4]))
                for batch in batches {
                    expect(batch.count).to(equal(1))
                }
            }

            it("caps batches at maxBatchSize when the payload limit is not hit") {
                let records: [[String: Any]] = (0..<5).map { ["i": $0] }
                let batches = SensorSampleUploadManager.splitRespectingPayloadLimit(records,
                                                                                    maxBatchSize: 2,
                                                                                    maxBatchBytes: 1024 * 1024)
                expect(batches.map { $0.count }).to(equal([2, 2, 1]))
                let flattened = batches.flatMap { $0 }.compactMap { $0["i"] as? Int }
                expect(flattened).to(equal([0, 1, 2, 3, 4]))
            }
        }
    }
}
