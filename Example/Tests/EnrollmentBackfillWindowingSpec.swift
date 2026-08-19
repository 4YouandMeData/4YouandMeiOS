//
//  EnrollmentBackfillWindowingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3841 / FUAM-3945: join-day-bounded backfill — pure-logic specs for the consent boundary.
//
//  The invariant these specs defend: no sample measured before the participant's study join day,
//  and nothing older than 365 days, may ever be transmitted; when the join day cannot be
//  established, collection is forward-only (never a legacy window).
//
//  Under test (all static, no HealthKit/SensorKit runtime needed):
//  - RepositoryImpl.enrollmentDate(fromDaysInStudy:now:calendar:)
//      backend semantics: days_in_study is 1 ON the join day
//      ((end_date - onboarding_date).to_i + 1), <= 0 is not a valid enrolled state.
//  - BackfillLowerBound.resolve(joinDay:now:)
//      the single join-day -> lower-bound policy shared by both subsystems: join day, floored
//      at 365 days, forward-only when the join day is unknown.
//  - SensorSampleUploadManager.buildWindowPlan(...)
//      first window never opens before the bound; upper bound honours the 24h embargo
//      (day-aligned for report sensors); empty plan when the bound has reached it.
//  - SensorSampleUploadManager.dropPreBoundRecords(_:lowerBound:windowStart:)
//      hard consent gate across the heterogeneous timestamp keys; records without a
//      parseable timestamp are kept only when the whole window is >= the bound.
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
        let hardCap: TimeInterval = 365 * day

        // 2026-08-10 12:00:00 UTC
        let now = Date(timeIntervalSince1970: 1786104000)
        let startOfToday = calendar.startOfDay(for: now)

        func iso(_ date: Date) -> String {
            return ISO8601DateFormatter().string(from: date)
        }

        describe("RepositoryImpl.enrollmentDate(fromDaysInStudy:)") {

            it("maps day-of-join (days_in_study == 1) to startOfDay(today)") {
                let result = RepositoryImpl.enrollmentDate(fromDaysInStudy: 1, now: now, calendar: calendar)
                expect(result).to(equal(startOfToday))
            }

            it("maps days_in_study == 2 to startOfDay(yesterday)") {
                let result = RepositoryImpl.enrollmentDate(fromDaysInStudy: 2, now: now, calendar: calendar)
                expect(result).to(equal(calendar.date(byAdding: .day, value: -1, to: startOfToday)))
            }

            it("maps days_in_study == 200 to 199 days before startOfDay(today)") {
                let result = RepositoryImpl.enrollmentDate(fromDaysInStudy: 200, now: now, calendar: calendar)
                expect(result).to(equal(calendar.date(byAdding: .day, value: -199, to: startOfToday)))
            }

            it("returns nil for days_in_study == 0") {
                expect(RepositoryImpl.enrollmentDate(fromDaysInStudy: 0, now: now, calendar: calendar)).to(beNil())
            }

            it("returns nil for negative days_in_study") {
                expect(RepositoryImpl.enrollmentDate(fromDaysInStudy: -3, now: now, calendar: calendar)).to(beNil())
            }
        }

        describe("RepositoryImpl.enrollmentCalendar(userTimeZone:)") {

            // Backend computes days_in_study in the USER's timezone (FUAM-3841 final review).
            let auckland = TimeZone(identifier: "Pacific/Auckland")!

            it("derives the join day boundary in the user's timezone, not the device's") {
                // `now` is 2026-08-10 12:00 UTC == 2026-08-11 00:00 NZST: the user-local day
                // boundary IS `now`, while a UTC (device-like) calendar lands 12h earlier —
                // a day early in user-local terms, the pre-fix bug.
                let userCalendar = RepositoryImpl.enrollmentCalendar(userTimeZone: auckland)
                let result = RepositoryImpl.enrollmentDate(fromDaysInStudy: 1, now: now, calendar: userCalendar)
                var aucklandCalendar = Calendar(identifier: .gregorian)
                aucklandCalendar.timeZone = auckland
                expect(result).to(equal(aucklandCalendar.startOfDay(for: now)))
                expect(result).toNot(equal(calendar.startOfDay(for: now)))
            }

            it("keeps a long enrolment anchored to the user's day boundary, not the device's") {
                // 30 days in study: the join day must be 29 user-local days before the user's
                // start of today. A device (UTC) calendar lands 12h earlier — one user-local
                // day early, which is exactly what would leak pre-consent data.
                let daysInStudy = 30
                var aucklandCalendar = Calendar(identifier: .gregorian)
                aucklandCalendar.timeZone = auckland
                let expected = aucklandCalendar.date(byAdding: .day,
                                                     value: -(daysInStudy - 1),
                                                     to: aucklandCalendar.startOfDay(for: now))
                let userCalendar = RepositoryImpl.enrollmentCalendar(userTimeZone: auckland)
                expect(RepositoryImpl.enrollmentDate(fromDaysInStudy: daysInStudy, now: now, calendar: userCalendar))
                    .to(equal(expected))
                expect(RepositoryImpl.enrollmentDate(fromDaysInStudy: daysInStudy, now: now, calendar: calendar))
                    .toNot(equal(expected))
            }

            it("falls back to the device timezone when the user record carries none") {
                expect(RepositoryImpl.enrollmentCalendar(userTimeZone: nil).timeZone).to(equal(Calendar.current.timeZone))
            }
        }

        describe("BackfillLowerBound.resolve") {

            it("uses the join day when it is within the 365-day cap") {
                let joinDay = now.addingTimeInterval(-200 * day)
                let bound = BackfillLowerBound.resolve(joinDay: joinDay, now: now)
                expect(bound.date).to(equal(joinDay))
                expect(bound.origin).to(equal(BackfillLowerBound.Origin.joinDate))
                expect(bound.origin.rawValue).to(equal("join_date"))
                expect(bound.isForwardOnly).to(beFalse())
            }

            it("clamps a join day older than 365 days to exactly now - 365 days") {
                let bound = BackfillLowerBound.resolve(joinDay: now.addingTimeInterval(-500 * day), now: now)
                expect(bound.date).to(equal(now.addingTimeInterval(-hardCap)))
                expect(bound.origin).to(equal(BackfillLowerBound.Origin.hardCap365d))
                expect(bound.origin.rawValue).to(equal("hard_cap_365d"))
            }

            it("keeps a join day exactly 365 days old (boundary is inclusive)") {
                let joinDay = now.addingTimeInterval(-hardCap)
                let bound = BackfillLowerBound.resolve(joinDay: joinDay, now: now)
                expect(bound.date).to(equal(joinDay))
                expect(bound.origin).to(equal(BackfillLowerBound.Origin.joinDate))
            }

            it("is forward-only when the join day cannot be established") {
                let bound = BackfillLowerBound.resolve(joinDay: nil, now: now)
                expect(bound.date).to(equal(now))
                expect(bound.origin).to(equal(BackfillLowerBound.Origin.forwardOnly))
                expect(bound.origin.rawValue).to(equal("forward_only"))
                expect(bound.isForwardOnly).to(beTrue())
            }

            it("emits the agreed bounded_by vocabulary") {
                expect(BackfillLowerBound.Origin.cursor.rawValue).to(equal("cursor"))
                expect(BackfillLowerBound.Origin.emptyPlan.rawValue).to(equal("empty_plan"))
                expect(BackfillLowerBound.Origin.gaveUp.rawValue).to(equal("gave_up"))
            }
        }

        describe("SensorSampleUploadManager.buildWindowPlan") {

            func plan(dayAggregated: Bool,
                      joinDay: Date?,
                      cursor: Date?) -> SensorSampleUploadManager.WindowPlan {
                return SensorSampleUploadManager.buildWindowPlan(dayAggregated: dayAggregated,
                                                                 now: now,
                                                                 joinDay: joinDay,
                                                                 cursor: cursor,
                                                                 embargo: embargo,
                                                                 calendar: calendar)
            }

            context("continuous sensor") {

                it("opens at the join day when it is within the 365-day cap") {
                    let joinDay = now.addingTimeInterval(-200 * day)
                    let result = plan(dayAggregated: false, joinDay: joinDay, cursor: nil)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.joinDate))
                    expect(result.lowerBound).to(equal(joinDay))
                    expect(result.windows.first?.start).to(equal(joinDay))
                }

                it("opens at exactly now - 365 days for a join day 500 days ago, never earlier") {
                    let result = plan(dayAggregated: false, joinDay: now.addingTimeInterval(-500 * day), cursor: nil)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.hardCap365d))
                    expect(result.windows.first?.start).to(equal(now.addingTimeInterval(-hardCap)))
                    for window in result.windows {
                        expect(window.start.timeIntervalSince(now)).to(beGreaterThanOrEqualTo(-hardCap))
                    }
                }

                it("never ends past the 24h embargo cutoff") {
                    let result = plan(dayAggregated: false, joinDay: now.addingTimeInterval(-3 * day), cursor: nil)
                    expect(result.windows.last?.end).to(equal(now.addingTimeInterval(-embargo)))
                    for window in result.windows {
                        expect(window.end.timeIntervalSince(now)).to(beLessThanOrEqualTo(-embargo))
                    }
                }

                it("resumes from a cursor ahead of the bound instead of re-uploading") {
                    let cursor = now.addingTimeInterval(-2 * day)
                    let result = plan(dayAggregated: false, joinDay: now.addingTimeInterval(-10 * day), cursor: cursor)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.cursor))
                    expect(result.lowerBound).to(equal(cursor))
                    expect(result.windows.first?.start).to(equal(cursor))
                }

                it("ignores a stale cursor behind the bound") {
                    let joinDay = now.addingTimeInterval(-3 * day)
                    let cursor = now.addingTimeInterval(-6 * day)
                    let result = plan(dayAggregated: false, joinDay: joinDay, cursor: cursor)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.joinDate))
                    expect(result.windows.first?.start).to(equal(joinDay))
                }

                it("returns an empty plan when the bound has reached the embargo cutoff") {
                    let result = plan(dayAggregated: false, joinDay: now.addingTimeInterval(-hour), cursor: nil)
                    expect(result.windows).to(beEmpty())
                }
            }

            context("day-aggregated (report) sensor") {

                it("never opens the first day-aligned window before a mid-day join day") {
                    // Review fix #2: startOfDay(from) used to rewind below the bound.
                    let joinDay = now.addingTimeInterval(-3 * day).addingTimeInterval(3.5 * hour)
                    let result = plan(dayAggregated: true, joinDay: joinDay, cursor: nil)
                    expect(result.windows.first?.start).to(equal(joinDay))
                    for window in result.windows {
                        expect(window.start.timeIntervalSince(joinDay)).to(beGreaterThanOrEqualTo(0))
                    }
                }

                it("day-aligns the resume point of a mid-day cursor without passing the bound") {
                    let joinDay = now.addingTimeInterval(-10 * day)
                    let cursor = now.addingTimeInterval(-2 * day).addingTimeInterval(5 * hour)
                    let result = plan(dayAggregated: true, joinDay: joinDay, cursor: cursor)
                    expect(result.windows.first?.start).to(equal(max(calendar.startOfDay(for: cursor), joinDay)))
                }

                it("ends on a day boundary at most 24h in the past (review fix #11)") {
                    let result = plan(dayAggregated: true, joinDay: now.addingTimeInterval(-10 * day), cursor: nil)
                    let expectedSafeTo = calendar.startOfDay(for: now.addingTimeInterval(-embargo))
                    expect(result.windows.last?.end).to(equal(expectedSafeTo))
                    for window in result.windows.dropFirst() {
                        expect(window.start).to(equal(calendar.startOfDay(for: window.start)))
                    }
                }

                it("returns an empty plan when the participant joined today (bound >= safeTo)") {
                    let result = plan(dayAggregated: true, joinDay: startOfToday, cursor: nil)
                    expect(result.windows).to(beEmpty())
                }

                it("clamps a 500-day-old join day to the 365-day cap here too") {
                    let result = plan(dayAggregated: true, joinDay: now.addingTimeInterval(-500 * day), cursor: nil)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.hardCap365d))
                    expect(result.windows.first?.start).to(equal(now.addingTimeInterval(-hardCap)))
                }
            }

            context("no resolvable join day (FUAM-3945: forward-only, never a legacy window)") {

                // The host consent-bypass flags (FYAMHealthKitIgnoreOptInConsent /
                // FYAMSensorKitIgnoreOptInConsent) are deliberately NOT inputs to this policy
                // any more, so forward-only holds with them on or off: there is no code path
                // left that can widen the bound. The specs below cover both subsystems' shared
                // policy (`BackfillLowerBound`) and the SensorKit plan built on top of it.
                it("is forward-only: the bound is now and the plan is empty, whatever the host flags say") {
                    for dayAggregated in [true, false] {
                        let result = plan(dayAggregated: dayAggregated, joinDay: nil, cursor: nil)
                        expect(result.lowerBound).to(equal(now))
                        expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.forwardOnly))
                        expect(result.windows).to(beEmpty())
                    }
                }

                it("does not reopen history from a stale cursor when the join day is unknown") {
                    // A cursor left behind by a previous enrolment must not become a backfill
                    // bound of its own: the window may only open at (or after) `now`.
                    let result = plan(dayAggregated: false, joinDay: nil, cursor: now.addingTimeInterval(-30 * day))
                    expect(result.lowerBound).to(equal(now))
                    expect(result.windows).to(beEmpty())
                }

                it("drops every record that could still arrive under a forward-only bound") {
                    let bound = BackfillLowerBound.resolve(joinDay: nil, now: now)
                    let records: [[String: Any]] = [["t": iso(now.addingTimeInterval(-hour))],
                                                    ["start": iso(now.addingTimeInterval(-2 * day))],
                                                    ["start_ms": Int(now.addingTimeInterval(-day).timeIntervalSince1970 * 1000)],
                                                    ["recorded_at": iso(now.addingTimeInterval(-hour))],
                                                    ["payload": "opaque"]]
                    let result = SensorSampleUploadManager.dropPreBoundRecords(records,
                                                                              lowerBound: bound.date,
                                                                              windowStart: now.addingTimeInterval(-day))
                    expect(result).to(beEmpty())
                }
            }

            it("produces contiguous windows (no gaps, no overlaps)") {
                let joinDay = now.addingTimeInterval(-5 * day)
                for dayAggregated in [true, false] {
                    let result = plan(dayAggregated: dayAggregated, joinDay: joinDay, cursor: nil)
                    for (previous, next) in zip(result.windows, result.windows.dropFirst()) {
                        expect(previous.end).to(equal(next.start))
                    }
                }
            }
        }

        describe("SensorSampleUploadManager.dropPreBoundRecords") {

            let lowerBound = now.addingTimeInterval(-3 * day)
            let before = lowerBound.addingTimeInterval(-hour)
            let after = lowerBound.addingTimeInterval(hour)
            let inBoundsWindowStart = lowerBound
            let outOfBoundsWindowStart = calendar.startOfDay(for: lowerBound)

            func drop(_ records: [[String: Any]], windowStart: Date) -> [[String: Any]] {
                return SensorSampleUploadManager.dropPreBoundRecords(records,
                                                                     lowerBound: lowerBound,
                                                                     windowStart: windowStart)
            }

            it("drops a pre-bound record keyed by 't'") {
                let result = drop([["t": iso(before)], ["t": iso(after)]], windowStart: inBoundsWindowStart)
                expect(result.count).to(equal(1))
                expect(result.first?["t"] as? String).to(equal(iso(after)))
            }

            it("drops a pre-bound record keyed by 'start'") {
                let result = drop([["start": iso(before)]], windowStart: inBoundsWindowStart)
                expect(result).to(beEmpty())
            }

            it("drops a pre-bound record keyed by 'start_ms'") {
                let beforeMs = Int(before.timeIntervalSince1970 * 1000)
                let result = drop([["start_ms": beforeMs]], windowStart: inBoundsWindowStart)
                expect(result).to(beEmpty())
            }

            it("drops a pre-bound record keyed by 'recorded_at'") {
                let result = drop([["recorded_at": iso(before)]], windowStart: inBoundsWindowStart)
                expect(result).to(beEmpty())
            }

            it("drops an unparseable record when the window opens below the bound (review fix #2)") {
                let result = drop([["payload": "opaque"]], windowStart: outOfBoundsWindowStart)
                expect(result).to(beEmpty())
            }

            it("keeps an unparseable record when the whole window is at or after the bound") {
                let result = drop([["payload": "opaque"]], windowStart: inBoundsWindowStart)
                expect(result.count).to(equal(1))
            }

            it("keeps a record measured exactly at the bound") {
                let result = drop([["t": iso(lowerBound)]], windowStart: inBoundsWindowStart)
                expect(result.count).to(equal(1))
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
