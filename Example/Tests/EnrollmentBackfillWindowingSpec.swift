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
//  - SensorSampleUploadManager.dropPreBoundRecords(_:lowerBound:windowStart:sensor:)
//      hard consent gate across the heterogeneous timestamp keys. `recorded_at` is a WRITE time
//      for every sensor and is never read as a measurement time; each sensor's real measurement
//      time is read where its mapper actually puts it (nested `arrival.start` for visits,
//      `recorded_at - duration_s` only for the three usage reports whose `duration` IS a span),
//      and a record with no readable measurement time survives only when its window vouches.
//  - SensorSampleUploadManager.handleWindowResult / .drainQueue
//      the same gate through its real call paths: the forward-only cursor guard, the
//      max(planned, re-resolved) bound, and the drain-time re-filter against the batch's own
//      window (SensorUploadConsentCallPathSpec, below).
//  - BackfillLowerBound.healthQuery(storedCursor:)
//      the three HealthKit enforcement points: forward-only skip, cursor clamped to the bound,
//      and the non-optional minimumSampleDate handed to the uploader.
//  - BackfillClock.monotonicNow(current:defaults:analytics:)
//      clock-rollback fail-safe for the join-day derivation, the throttled persistence of the
//      high-water mark, and the `sensor_data_clock_ahead` diagnostic for the opposite (forward)
//      jump, which suspends collection until real time catches up.
//  - HealthSampleUploadManager.startUpload(forUploader:)
//      the chunk walk skips a data type whose start date has reached the end of the window
//      WITHOUT persisting a cursor, so a bound stuck in the future costs nothing permanently;
//      and the FUAM-3945 payload-size defence: an oversize chunk is bisected by TIME, the
//      recursion stops at `MinimumChunkDuration`, a floor-sized chunk that still fails is
//      forfeited + reported without blocking the rest, the cursor never moves past a sub-window
//      that did not succeed, and one chunk cannot burn more than `MaxChunkUploadAttempts`
//      (HealthBackfillChunkWalkSpec, below).
//  - SensorSampleUploadManager.splitRespectingPayloadLimit(_:maxBatchSize:maxBatchBytes:)
//      bisection terminates on a single oversized record and preserves order.
//

import Quick
import Nimble
import RxSwift
import SensorKit
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
                expect(BackfillLowerBound.Origin.drainFiltered.rawValue).to(equal("drain_filtered"))
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
                // any more — there is no code path left that could widen the bound, hence
                // nothing about them to inject here. What IS varied below is the sensor kind:
                // both the continuous and the day-aggregated plan must come out empty.
                it("is forward-only for continuous and day-aggregated sensors alike: bound is now, plan is empty") {
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
                                                    ["arrival": ["start": iso(now.addingTimeInterval(-hour))]],
                                                    ["payload": "opaque"]]
                    for sensor in [SRSensor.accelerometer, .deviceUsageReport, .keyboardMetrics, .visits] {
                        let result = SensorSampleUploadManager.dropPreBoundRecords(records,
                                                                                   lowerBound: bound.date,
                                                                                   windowStart: now.addingTimeInterval(-day),
                                                                                   sensor: sensor)
                        expect(result).to(beEmpty())
                    }
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

            func drop(_ records: [[String: Any]],
                      windowStart: Date,
                      sensor: SRSensor = .accelerometer) -> [[String: Any]] {
                return SensorSampleUploadManager.dropPreBoundRecords(records,
                                                                     lowerBound: lowerBound,
                                                                     windowStart: windowStart,
                                                                     sensor: sensor)
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

            // Review round 3, C2: `recorded_at` is SRFetchResult.timestamp — a WRITE time — for
            // every client-push sensor. It may never vouch for a record on any sensor.
            it("never accepts recorded_at as a measurement time") {
                let record: [String: Any] = ["recorded_at": iso(after)]
                // Only the window can save it, and this one opens below the bound.
                expect(drop([record], windowStart: outOfBoundsWindowStart)).to(beEmpty())
                // The same record survives an in-bounds window as an undecidable record, not
                // because its write time looked like a measurement.
                expect(drop([record], windowStart: inBoundsWindowStart).count).to(equal(1))
            }

            it("prefers the real measurement time over the write time") {
                let record: [String: Any] = ["t": iso(before), "recorded_at": iso(after)]
                expect(drop([record], windowStart: inBoundsWindowStart)).to(beEmpty())
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

            // Review fix #1. The four day-aggregated report sensors carry `recorded_at` =
            // SRFetchResult.timestamp — WHEN SensorKit wrote the report, not the period it
            // describes. Only the three USAGE reports also carry a `duration` that IS the span
            // the report covers (review round 3, C1: keyboard metrics do not).
            context("day-aggregated usage reports (device / phone / messages)") {

                // The first window of a backfill opens exactly AT the join day; a report
                // written during it describes the previous, pre-consent day.
                let firstWindowStart = lowerBound
                let laterWindowStart = lowerBound.addingTimeInterval(day)

                it("drops a report written after the bound that describes the pre-join day") {
                    let record: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(2 * hour)),
                                                 "duration_s": day]
                    expect(drop([record], windowStart: firstWindowStart, sensor: .deviceUsageReport)).to(beEmpty())
                }

                it("keeps a report whose derived period start is at or after the bound") {
                    let record: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(26 * hour)),
                                                 "duration_s": day]
                    expect(drop([record], windowStart: laterWindowStart, sensor: .phoneUsageReport).count).to(equal(1))
                }

                it("keeps a report whose period starts exactly at the bound") {
                    let record: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(day)),
                                                 "duration_s": day]
                    expect(drop([record], windowStart: laterWindowStart, sensor: .messagesUsageReport).count).to(equal(1))
                }

                it("prefers an explicit period start over the recorded_at/duration derivation") {
                    let preBound: [String: Any] = ["start": iso(before),
                                                   "recorded_at": iso(after),
                                                   "duration_s": 0]
                    expect(drop([preBound], windowStart: laterWindowStart, sensor: .deviceUsageReport)).to(beEmpty())
                    let inBound: [String: Any] = ["start": iso(after),
                                                  "recorded_at": iso(after.addingTimeInterval(day)),
                                                  "duration_s": 10 * day]
                    expect(drop([inBound], windowStart: laterWindowStart, sensor: .deviceUsageReport).count).to(equal(1))
                }

                // Review round 3, C1: a duration that cannot be a report span must not be
                // turned into one — the record is undecidable, and the window decides.
                it("refuses an implausibly short duration_s as a period length") {
                    let record: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(2 * hour)),
                                                 "duration_s": 30 * 60]
                    expect(drop([record], windowStart: firstWindowStart, sensor: .deviceUsageReport)).to(beEmpty())
                    expect(drop([record], windowStart: laterWindowStart, sensor: .deviceUsageReport).count).to(equal(1))
                }

                it("refuses a zero or negative duration_s as a period length") {
                    for duration in [0, -day] {
                        let record: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(2 * hour)),
                                                     "duration_s": duration]
                        expect(drop([record], windowStart: firstWindowStart, sensor: .deviceUsageReport)).to(beEmpty())
                    }
                }

                it("drops a report with no derivable period start unless the window is strictly above the bound") {
                    let record: [String: Any] = ["recorded_at": iso(after)]
                    // Window opening AT the bound: undecidable ⇒ drop.
                    expect(drop([record], windowStart: firstWindowStart, sensor: .deviceUsageReport)).to(beEmpty())
                    // Window entirely above the bound: nothing it can contain predates consent.
                    expect(drop([record], windowStart: laterWindowStart, sensor: .deviceUsageReport).count).to(equal(1))
                }

                it("drops an unparseable report unless the window is strictly above the bound") {
                    expect(drop([["payload": "opaque"]],
                                windowStart: firstWindowStart, sensor: .messagesUsageReport)).to(beEmpty())
                    expect(drop([["payload": "opaque"]],
                                windowStart: laterWindowStart, sensor: .messagesUsageReport).count).to(equal(1))
                }
            }

            // Review round 3, C1. `SRKeyboardMetrics.duration` is cumulative typing/session time
            // (minutes), NOT the span the report covers: deriving `recorded_at − duration_s` from
            // it put a whole pre-consent day of keyboard metrics back inside the bound.
            context("keyboard metrics (duration is not a report period)") {

                let firstWindowStart = lowerBound
                let laterWindowStart = lowerBound.addingTimeInterval(day)

                it("never derives a period start from a cumulative typing duration") {
                    // 30 minutes of typing written one hour into the join day used to look like
                    // a period starting 30 minutes BEFORE it.
                    let typing: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(hour)),
                                                 "duration_s": 1800]
                    expect(drop([typing], windowStart: firstWindowStart, sensor: .keyboardMetrics)).to(beEmpty())
                    // Even a duration that WOULD be a plausible span is refused for this sensor…
                    let fullDay: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(26 * hour)),
                                                  "duration_s": day]
                    expect(drop([fullDay], windowStart: firstWindowStart, sensor: .keyboardMetrics)).to(beEmpty())
                    // …while the very same payload IS derivable for a real usage report.
                    expect(drop([fullDay], windowStart: firstWindowStart, sensor: .deviceUsageReport).count).to(equal(1))
                }

                it("gates keyboard metrics on an explicit start when the OS exposes one") {
                    let preBound: [String: Any] = ["start": iso(before), "recorded_at": iso(after), "duration_s": 1800]
                    expect(drop([preBound], windowStart: laterWindowStart, sensor: .keyboardMetrics)).to(beEmpty())
                    let inBound: [String: Any] = ["start": iso(after), "recorded_at": iso(after), "duration_s": 1800]
                    expect(drop([inBound], windowStart: firstWindowStart, sensor: .keyboardMetrics).count).to(equal(1))
                }
            }

            // Review round 3, C2. `VisitsMapper` puts the write time in `recorded_at` and the
            // real measurement times in the nested arrival/departure intervals. Production
            // evidence (user 631, IntegrationData 254107980): seven records sharing one
            // `recorded_at` while their arrivals span the three previous days.
            context("visits (measurement time is nested, write lag is days)") {

                it("gates a visit on its nested arrival.start, not on the write time") {
                    let preJoin: [String: Any] = ["recorded_at": iso(after),
                                                  "arrival": ["start": iso(before), "end": iso(before)],
                                                  "location_category": "home"]
                    expect(drop([preJoin], windowStart: inBoundsWindowStart, sensor: .visits)).to(beEmpty())
                    let postJoin: [String: Any] = ["recorded_at": iso(after.addingTimeInterval(2 * day)),
                                                   "arrival": ["start": iso(after), "end": iso(after)]]
                    expect(drop([postJoin], windowStart: inBoundsWindowStart, sensor: .visits).count).to(equal(1))
                }

                it("falls back to departure.start when the arrival interval is missing") {
                    let preJoin: [String: Any] = ["recorded_at": iso(after),
                                                  "departure": ["start": iso(before), "end": iso(before)]]
                    expect(drop([preJoin], windowStart: inBoundsWindowStart, sensor: .visits)).to(beEmpty())
                    let postJoin: [String: Any] = ["recorded_at": iso(after),
                                                   "departure": ["start": iso(after), "end": iso(after)]]
                    expect(drop([postJoin], windowStart: inBoundsWindowStart, sensor: .visits).count).to(equal(1))
                }

                it("never lets the fetch window vouch for a visit with no nested time") {
                    // Visits are indexed by write time, so no window — however far above the
                    // bound it opens — proves when the visit happened.
                    let record: [String: Any] = ["recorded_at": iso(after), "location_category": "home"]
                    expect(drop([record], windowStart: inBoundsWindowStart, sensor: .visits)).to(beEmpty())
                    expect(drop([record],
                                windowStart: lowerBound.addingTimeInterval(10 * day), sensor: .visits)).to(beEmpty())
                }
            }

            it("treats a media event as undecidable: SRMediaEvent carries no date of its own") {
                guard #available(iOS 16.4, *) else { return }
                let record: [String: Any] = ["recorded_at": iso(after), "event_type": "play"]
                expect(drop([record], windowStart: outOfBoundsWindowStart, sensor: .mediaEvents)).to(beEmpty())
                expect(drop([record], windowStart: inBoundsWindowStart, sensor: .mediaEvents).count).to(equal(1))
            }

            // Review fix #2 + review round 3 (I1): the persisted batch queue is re-filtered
            // immediately before upload, against the window the batch was FETCHED from — which
            // is persisted with it. `.distantPast` used to stand in for it, which silently
            // destroyed every undecidable record in the queue, permanently.
            context("re-filtering a persisted batch at drain time") {

                it("keeps an undecidable record when the batch's own window vouches for it") {
                    let records: [[String: Any]] = [["t": iso(before)], ["t": iso(after)], ["payload": "opaque"]]
                    let result = drop(records, windowStart: inBoundsWindowStart)
                    expect(result.count).to(equal(2))
                    expect(result.first?["t"] as? String).to(equal(iso(after)))
                }

                it("still drops everything undecidable when the batch's window opened below the bound") {
                    let records: [[String: Any]] = [["t": iso(before)], ["t": iso(after)], ["payload": "opaque"]]
                    let result = drop(records, windowStart: outOfBoundsWindowStart)
                    expect(result.count).to(equal(1))
                    expect(result.first?["t"] as? String).to(equal(iso(after)))
                }

                it("drops a queued day aggregate that describes the pre-join day") {
                    let record: [String: Any] = ["recorded_at": iso(lowerBound.addingTimeInterval(2 * hour)),
                                                 "duration_s": day]
                    expect(drop([record], windowStart: inBoundsWindowStart, sensor: .deviceUsageReport)).to(beEmpty())
                }
            }
        }

        describe("BackfillLowerBound.healthQuery (HealthKit enforcement points)") {

            let joinDay = now.addingTimeInterval(-100 * day)
            let bound = BackfillLowerBound.resolve(joinDay: joinDay, now: now)

            it("skips the data type entirely when the join day is unknown (forward-only)") {
                // nil means SKIP, and the caller must leave the stored cursor untouched, so the
                // real backfill still runs once the join day resolves.
                let forwardOnly = BackfillLowerBound.resolve(joinDay: nil, now: now)
                expect(forwardOnly.healthQuery(storedCursor: nil)).to(beNil())
                expect(forwardOnly.healthQuery(storedCursor: now.addingTimeInterval(-30 * day))).to(beNil())
            }

            it("starts the walk at the bound when no cursor exists yet") {
                expect(bound.healthQuery(storedCursor: nil)?.startDate).to(equal(joinDay))
            }

            it("clamps a stored cursor that predates the bound up to the bound") {
                let staleCursor = joinDay.addingTimeInterval(-50 * day)
                expect(bound.healthQuery(storedCursor: staleCursor)?.startDate).to(equal(joinDay))
            }

            it("resumes from a stored cursor ahead of the bound") {
                let cursor = joinDay.addingTimeInterval(10 * day)
                expect(bound.healthQuery(storedCursor: cursor)?.startDate).to(equal(cursor))
            }

            it("always hands the uploader the bound itself as minimumSampleDate, never the cursor") {
                let cursor = joinDay.addingTimeInterval(10 * day)
                expect(bound.healthQuery(storedCursor: cursor)?.minimumSampleDate).to(equal(bound.date))
                expect(bound.healthQuery(storedCursor: nil)?.minimumSampleDate).to(equal(bound.date))
            }

            it("caps minimumSampleDate at the 365-day hard cap for an ancient join day") {
                let old = BackfillLowerBound.resolve(joinDay: now.addingTimeInterval(-500 * day), now: now)
                let query = old.healthQuery(storedCursor: now.addingTimeInterval(-400 * day))
                expect(query?.minimumSampleDate).to(equal(now.addingTimeInterval(-hardCap)))
                expect(query?.startDate).to(equal(now.addingTimeInterval(-hardCap)))
            }
        }

        describe("BackfillClock.monotonicNow (clock-rollback fail-safe)") {

            var defaults: UserDefaults!

            beforeEach {
                defaults = UserDefaults(suiteName: "BackfillClockSpec.\(UUID().uuidString)")
            }

            it("returns the current date and records it when the clock moves forward") {
                expect(BackfillClock.monotonicNow(current: now, defaults: defaults)).to(equal(now))
                let later = now.addingTimeInterval(day)
                expect(BackfillClock.monotonicNow(current: later, defaults: defaults)).to(equal(later))
                expect(defaults.object(forKey: BackfillClock.storageKey) as? Date).to(equal(later))
            }

            it("keeps the high-water mark when the device clock is wound back") {
                _ = BackfillClock.monotonicNow(current: now, defaults: defaults)
                let rolledBack = now.addingTimeInterval(-30 * day)
                expect(BackfillClock.monotonicNow(current: rolledBack, defaults: defaults)).to(equal(now))
                expect(defaults.object(forKey: BackfillClock.storageKey) as? Date).to(equal(now))
            }

            it("does not rewrite the mark for a sub-minute advance (persistence throttle)") {
                _ = BackfillClock.monotonicNow(current: now, defaults: defaults)
                let barelyLater = now.addingTimeInterval(30)
                // The returned value is always the honest one; only the WRITE is throttled.
                expect(BackfillClock.monotonicNow(current: barelyLater, defaults: defaults)).to(equal(barelyLater))
                expect(defaults.object(forKey: BackfillClock.storageKey) as? Date).to(equal(now))
            }

            it("rewrites the mark once the advance passes the granularity") {
                _ = BackfillClock.monotonicNow(current: now, defaults: defaults)
                let later = now.addingTimeInterval(BackfillClock.persistenceGranularity + 1)
                _ = BackfillClock.monotonicNow(current: later, defaults: defaults)
                expect(defaults.object(forKey: BackfillClock.storageKey) as? Date).to(equal(later))
            }

            it("never lets the throttle write a mark lower than the stored one") {
                _ = BackfillClock.monotonicNow(current: now, defaults: defaults)
                let smallRollback = now.addingTimeInterval(-10)
                expect(BackfillClock.monotonicNow(current: smallRollback, defaults: defaults)).to(equal(now))
                expect(defaults.object(forKey: BackfillClock.storageKey) as? Date).to(equal(now))
            }

            it("keeps the join day where it was after a 30-day rollback") {
                // The leak this defends: a 30-day rollback used to move the derived join day
                // 30 days earlier, and the plan and the per-record filter agreed on it.
                _ = BackfillClock.monotonicNow(current: now, defaults: defaults)
                let rolledBack = now.addingTimeInterval(-30 * day)
                let honest = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10, now: now, calendar: calendar)
                let naive = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10, now: rolledBack, calendar: calendar)
                let defended = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10,
                                                             now: BackfillClock.monotonicNow(current: rolledBack,
                                                                                             defaults: defaults),
                                                             calendar: calendar)
                expect(naive).to(beLessThan(honest))
                expect(defended).to(equal(honest))
            }

            context("the clock jumped FORWARD (the accepted residual, FUAM-3945 round 4 I2)") {

                var analytics: CapturingAnalyticsService!

                beforeEach {
                    analytics = CapturingAnalyticsService()
                    BackfillClock.clockAheadReported = false
                }

                func clockAheadEvents(_ events: [AnalyticsEvent]) -> [(mark: String, deviceNow: String)] {
                    return events.compactMap { event in
                        if case let .sensorDataClockAhead(mark, deviceNow) = event { return (mark, deviceNow) }
                        return nil
                    }
                }

                it("reports the mark and the device clock once per launch when the mark is over a day ahead") {
                    let jumped = now.addingTimeInterval(10 * day)
                    _ = BackfillClock.monotonicNow(current: jumped, defaults: defaults)

                    // Clock corrected: the mark stays ahead, so the bound is pinned in the future
                    // and collection is suspended. That must not be silent.
                    _ = BackfillClock.monotonicNow(current: now, defaults: defaults, analytics: analytics)
                    _ = BackfillClock.monotonicNow(current: now, defaults: defaults, analytics: analytics)

                    let reported = clockAheadEvents(analytics.trackedEvents)
                    expect(reported.count).to(equal(1))
                    expect(reported.first?.mark).to(equal(iso(jumped)))
                    expect(reported.first?.deviceNow).to(equal(iso(now)))
                }

                it("stays silent for a mark less than a day ahead (clock jitter, not a jump)") {
                    _ = BackfillClock.monotonicNow(current: now.addingTimeInterval(hour), defaults: defaults)
                    _ = BackfillClock.monotonicNow(current: now, defaults: defaults, analytics: analytics)
                    expect(clockAheadEvents(analytics.trackedEvents)).to(beEmpty())
                }
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

// MARK: - The consent gate through its real call paths (FUAM-3945 review round 3, I3)

/// Three fixes previously had no spec that fails when they are reverted, because the specs called
/// the pure gate directly and passed the very argument the fix is about. These drive the manager's
/// own call paths instead: `drainQueue` (the drain-time re-filter, I1) and `handleWindowResult`
/// (the forward-only cursor guard, review fix #4; the `max(planned, re-resolved)` bound, #5).
class SensorUploadConsentCallPathSpec: QuickSpec {

    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let sensor = SRSensor.accelerometer

        func iso(_ date: Date) -> String {
            return ISO8601DateFormatter().string(from: date)
        }

        func drainOrigins(_ events: [AnalyticsEvent]) -> [String] {
            return events.compactMap { event in
                if case let .sensorDataBackfillReach(_, _, boundedBy) = event { return boundedBy }
                return nil
            }
        }

        var storage: FakeSensorStorage!
        var analytics: CapturingAnalyticsService!
        var clearance: FakeSensorClearance!
        var mapper: FakeSensorMapper!
        var network: FakeSensorNetwork!
        var manager: SensorSampleUploadManager!
        var joinDay: Date!

        beforeEach {
            joinDay = Date().addingTimeInterval(-30 * day)
            storage = FakeSensorStorage()
            analytics = CapturingAnalyticsService()
            clearance = FakeSensorClearance()
            clearance.enrollmentDate = joinDay
            mapper = FakeSensorMapper()
            network = FakeSensorNetwork()
            manager = SensorSampleUploadManager(withSensors: [sensor],
                                                storage: storage,
                                                reachability: FakeSensorReachability(),
                                                analytics: analytics,
                                                mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance
            manager.setNetworkDelegate(network)
        }

        describe("drainQueue (the drain-time re-filter)") {

            it("re-filters a queued batch against the window it was actually fetched from") {
                storage.seed(records: [["t": iso(joinDay.addingTimeInterval(hour))],
                                       ["t": iso(joinDay.addingTimeInterval(-hour))],
                                       ["payload": "opaque"]],
                             windowStart: joinDay,
                             for: sensor)

                manager.drainQueue(for: sensor)

                expect(network.uploaded.count).toEventually(equal(1))
                // The pre-bound record is dropped. The undecidable one survives because the
                // batch's OWN window opened at the bound — passing `.distantPast` here (the bug)
                // would destroy it, and only the filtered batch is ever re-enqueued.
                expect(network.uploaded.first?.count).to(equal(2))
            }

            it("keeps holding the whole queue while the join day is unknown") {
                clearance.enrollmentDate = nil
                storage.seed(records: [["t": iso(joinDay.addingTimeInterval(hour))]],
                             windowStart: joinDay,
                             for: sensor)

                manager.drainQueue(for: sensor)

                expect(network.uploaded).toAlways(beEmpty(), until: .milliseconds(200))
                expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
            }

            it("leaves a drain_filtered trace when the gate drops records at drain time") {
                storage.seed(records: [["t": iso(joinDay.addingTimeInterval(hour))],
                                       ["t": iso(joinDay.addingTimeInterval(-hour))]],
                             windowStart: joinDay,
                             for: sensor)

                manager.drainQueue(for: sensor)

                expect(network.uploaded.count).toEventually(equal(1))
                expect(drainOrigins(analytics.trackedEvents)).to(contain("drain_filtered"))
            }

            it("stays silent when the drain-time gate drops nothing") {
                storage.seed(records: [["t": iso(joinDay.addingTimeInterval(hour))]],
                             windowStart: joinDay,
                             for: sensor)

                manager.drainQueue(for: sensor)

                expect(network.uploaded.count).toEventually(equal(1))
                expect(drainOrigins(analytics.trackedEvents)).toNot(contain("drain_filtered"))
            }
        }

        describe("handleWindowResult (the per-window consent decisions)") {

            it("leaves the cursor untouched and stops the chain when the user disappears mid-flight") {
                // Review fix #4: logout / session expiry between plan build and callback makes
                // the re-resolved bound forward-only. Advancing the cursor over the remaining
                // windows would forfeit them for good.
                clearance.enrollmentDate = nil
                let first = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))
                let second = DateInterval(start: first.end, end: first.end.addingTimeInterval(day))

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(hour))]]),
                                           window: first,
                                           at: 0,
                                           of: [first, second],
                                           for: sensor,
                                           using: mapper,
                                           plannedBound: joinDay)

                expect(storage.lastCursor(for: sensor)).to(beNil())
                expect(mapper.windows).to(beEmpty())
                expect(storage.enqueued).to(beEmpty())
            }

            it("gates on the planned bound when a mid-flight refresh moved the join day earlier") {
                // Review fix #5: `days_in_study` is not immutable. A live record claiming an
                // EARLIER join day must not widen the bound the plan was built with.
                clearance.enrollmentDate = joinDay.addingTimeInterval(-7 * day)
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(-hour))]]),
                                           window: window,
                                           at: 0,
                                           of: [window],
                                           for: sensor,
                                           using: mapper,
                                           plannedBound: joinDay)

                expect(storage.enqueued).to(beEmpty())

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(hour))]]),
                                           window: window,
                                           at: 0,
                                           of: [window],
                                           for: sensor,
                                           using: mapper,
                                           plannedBound: joinDay)

                expect(storage.enqueued.count).toEventually(equal(1))
            }

            it("gates on the re-resolved bound when the refresh moved the join day later") {
                clearance.enrollmentDate = joinDay.addingTimeInterval(7 * day)
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(hour))]]),
                                           window: window,
                                           at: 0,
                                           of: [window],
                                           for: sensor,
                                           using: mapper,
                                           plannedBound: joinDay)

                expect(storage.enqueued).to(beEmpty())
            }

            it("persists the fetch window alongside the batch it enqueues") {
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(hour))]]),
                                           window: window,
                                           at: 0,
                                           of: [window],
                                           for: sensor,
                                           using: mapper,
                                           plannedBound: joinDay)

                expect(storage.enqueued.count).toEventually(equal(1))
                expect(storage.enqueued.first?.windowStart).to(equal(window.start))
            }
        }
    }
}

// MARK: - Fakes

/// `NSLocking.withLock` is iOS 16+; the deployment target here is 15.6.
private extension NSLock {
    func locked<T>(_ body: () -> T) -> T {
        self.lock()
        defer { self.unlock() }
        return body()
    }
}

private final class FakeSensorStorage: SensorSampleUploadManagerStorage, SensorSampleUploaderStorage {

    private let lock = NSLock()
    private var cursors: [String: Date] = [:]
    private var queues: [String: [(records: [[String: Any]], windowStart: Date)]] = [:]
    private var enqueuedBatches: [(records: [[String: Any]], windowStart: Date)] = []

    /// Every batch ever enqueued, kept even after it is dequeued (audit log for the specs).
    var enqueued: [(records: [[String: Any]], windowStart: Date)] {
        return self.lock.locked { self.enqueuedBatches }
    }

    func seed(records: [[String: Any]], windowStart: Date, for sensor: SRSensor) {
        self.lock.locked { self.queues[sensor.rawValue] = [(records, windowStart)] }
    }

    func lastCursor(for sensor: SRSensor) -> Date? {
        return self.lock.locked { self.cursors[sensor.rawValue] }
    }

    func setLastCursor(_ date: Date, for sensor: SRSensor) {
        self.lock.locked { self.cursors[sensor.rawValue] = date }
    }

    func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) {
        self.lock.locked {
            self.queues[sensor.rawValue, default: []].append((batch, windowStart))
            self.enqueuedBatches.append((batch, windowStart))
        }
    }

    func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)? {
        return self.lock.locked {
            guard var queue = self.queues[sensor.rawValue], !queue.isEmpty else { return nil }
            let head = queue.removeFirst()
            self.queues[sensor.rawValue] = queue
            return head
        }
    }

    func pendingBatchCount(for sensor: SRSensor) -> Int {
        return self.lock.locked { self.queues[sensor.rawValue]?.count ?? 0 }
    }
}

private final class FakeSensorReachability: SensorSampleUploadManagerReachability {
    var isReachable: Bool = true
    var reachabilityChanged: Observable<Bool> { return .empty() }
}

private final class FakeSensorClearance: SensorSampleUploadManagerClearanceDelegate {
    var sensorManagerCanRun: Bool = true
    var enrollmentDate: Date?
}

private final class FakeSensorMapper: SensorSampleMapper {
    private let lock = NSLock()
    private var fetched: [DateInterval] = []

    var windows: [DateInterval] { return self.lock.locked { self.fetched } }

    func fetchAndMap(from: Date, to: Date, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        self.lock.locked { self.fetched.append(DateInterval(start: from, end: to)) }
        completion(.success([]))
    }
}

private final class FakeSensorNetwork: SensorSampleUploaderNetworkDelegate {
    private let lock = NSLock()
    private var payloads: [[[String: Any]]] = []

    var uploaded: [[[String: Any]]] { return self.lock.locked { self.payloads } }

    func uploadSensorBatch(sensor: SRSensor, payload: [[String: Any]]) -> Single<Void> {
        self.lock.locked { self.payloads.append(payload) }
        return .just(())
    }
}

// MARK: - The HealthKit chunk walk under a future bound (FUAM-3945 review round 4, I2)

/// The backfill bound can land in the FUTURE: the device clock jumped forward, so `BackfillClock`'s
/// high-water mark — and the join day derived from it — stay ahead of real time until it catches up.
/// The chunk walk then covers nothing, and the loop used to persist `nextEndDate` on every cycle
/// anyway, forfeiting the whole suspended window even after the clock was corrected. These specs
/// drive `startUpload(forUploader:)` itself: no HealthKit query is ever issued once the guard holds,
/// which is exactly what makes them synchronous.
class HealthBackfillChunkWalkSpec: QuickSpec {

    override class func spec() {

        let day: TimeInterval = 24 * 3600
        let dataType = HealthDataType.stepCount

        var storage: FakeHealthStorage!
        var analytics: CapturingAnalyticsService!
        var clearance: FakeHealthClearance!
        var network: FakeHealthNetwork!

        beforeEach {
            storage = FakeHealthStorage()
            analytics = CapturingAnalyticsService()
            clearance = FakeHealthClearance()
            network = FakeHealthNetwork()
            // A join day in the future: only reachable through a forward clock jump.
            clearance.enrollmentDate = Date().addingTimeInterval(5 * day)
        }

        func makeManager() -> HealthSampleUploadManager {
            let manager = HealthSampleUploadManager(withDataTypes: [dataType],
                                                    storage: storage,
                                                    reachability: FakeHealthReachability(),
                                                    analytics: analytics)
            manager.clearanceDelegate = clearance
            manager.setNetworkDelegate(network)
            return manager
        }

        it("skips a data type whose start date has reached the end of the window, cursor unwritten") {
            let manager = makeManager()
            guard let uploader = manager.uploaders.first else {
                fail("no uploader for \(dataType.keyName)")
                return
            }

            manager.startUpload(forUploader: uploader)

            // Synchronous: nothing was queried, so the sequence has already moved past this type.
            expect(storage.pendingUploadDataType).to(beNil())
            expect(storage.uploadStartDate(forDataType: dataType)).toAlways(beNil(), until: .milliseconds(200))
        }

        it("leaves an existing cursor exactly where it was, so the suspended window is not lost") {
            let cursor = Date().addingTimeInterval(-3 * day)
            storage.setUploadStartDate(cursor, forDataType: dataType)
            let manager = makeManager()
            guard let uploader = manager.uploaders.first else {
                fail("no uploader for \(dataType.keyName)")
                return
            }

            manager.startUpload(forUploader: uploader)

            // Same synchronous tell as above: a walk that started would still be pending here.
            expect(storage.pendingUploadDataType).to(beNil())
            expect(storage.uploadStartDate(forDataType: dataType)).toAlways(equal(cursor), until: .milliseconds(200))
        }

        // MARK: - FUAM-3945 payload-size defence
        //
        // The server caps one request at 10 MB and the walk cannot advance past a rejected chunk,
        // so a single dense day used to stall the data type for ever (retried on every sequence,
        // no telemetry). These drive the REAL walk — `startUpload(forUploader:)` — through the
        // `uploadChunk` seam, because a simulator's HealthKit store cannot be seeded.
        describe("oversize chunks") {

            let hour: TimeInterval = 3600
            let minute: TimeInterval = 60
            // 90 minutes back: the head path (1-hour chunks), i.e. exactly two chunks —
            // [cursor, cursor+1h) and [cursor+1h, now] — and no sliver in between.
            var cursor: Date!
            var attempted: [DateInterval]!

            beforeEach {
                clearance.enrollmentDate = Date().addingTimeInterval(-10 * day)
                cursor = Date().addingTimeInterval(-90 * minute)
                storage.setUploadStartDate(cursor, forDataType: dataType)
                attempted = []
            }

            /// Runs the walk with `rule` deciding each chunk's outcome, recording every attempt.
            func walk(_ rule: @escaping (DateInterval) -> HealthSampleUploaderError?) {
                let manager = makeManager()
                guard let uploader = manager.uploaders.first else {
                    fail("no uploader for \(dataType.keyName)")
                    return
                }
                manager.uploadChunk = { _, chunk, _, _ in
                    attempted.append(chunk)
                    if let error = rule(chunk) {
                        return Single.error(error)
                    }
                    return Single.just(())
                }
                manager.startUpload(forUploader: uploader)
            }

            func reachEvents(boundedBy origin: BackfillLowerBound.Origin) -> [String] {
                return analytics.trackedEvents.compactMap { event in
                    guard case .sensorDataBackfillReach(let sensor, let reachedBack, let boundedBy) = event,
                          boundedBy == origin.rawValue,
                          sensor == "health_kit_" + dataType.keyName else { return nil }
                    return reachedBack
                }
            }

            it("bisects an oversize chunk by time and uploads both halves") {
                walk { $0.duration >= hour ? .uploadPayloadTooLarge : nil }

                // The 1-hour chunk, then its two halves in chronological order, then the tail
                // (whose end is the walk's own `Date()`, hence not asserted).
                expect(attempted.map { $0.start }).to(equal([cursor, cursor, cursor + 30 * minute, cursor + hour]))
                expect(Array(attempted.map { $0.end }.dropLast()))
                    .to(equal([cursor + hour, cursor + 30 * minute, cursor + hour]))
                // Nothing was forfeited, and the walk ran to the end of the window.
                expect(reachEvents(boundedBy: .gaveUp)).to(beEmpty())
                expect(reachEvents(boundedBy: .bisected).count).to(equal(1))
                expect(storage.uploadStartDate(forDataType: dataType)).to(equal(attempted.last?.end))
            }

            it("stops halving at the floor instead of recursing for ever") {
                // Only the sub-windows anchored at the cursor fail, so the failing chain is a
                // clean 1h -> 30min -> 15min descent with no wall-clock sliver in it.
                walk { $0.start == cursor ? .uploadPayloadTooLarge : nil }

                let failedSpans = attempted.filter { $0.start == cursor }.map { $0.duration }
                expect(failedSpans).to(equal([hour, 30 * minute, 15 * minute]))
                expect(Constants.HealthKit.MinimumChunkDuration).to(equal(15 * minute))
                // One forfeit — the floor-sized sub-window — and nothing narrower was retried.
                expect(reachEvents(boundedBy: .gaveUp).count).to(equal(1))
            }

            it("forfeits a floor-sized chunk that still fails, reports it, and keeps going") {
                // Everything inside the first hour is impossible; the second chunk is fine.
                walk { $0.start < cursor + hour ? .uploadPayloadTooLarge : nil }

                // Four 15-minute forfeits cover the hour, each one reported (it IS data loss).
                let forfeits = reachEvents(boundedBy: .gaveUp)
                expect(forfeits.count).to(equal(4))
                expect(Set(forfeits).count).to(equal(4))
                // The rest of the data type kept flowing, and the cursor is past the whole window.
                let tail = attempted.filter { $0.start >= cursor + hour }
                expect(tail.count).to(equal(1))
                expect(storage.uploadStartDate(forDataType: dataType)).to(equal(tail.first?.end))
            }

            it("never advances the cursor past a sub-window that did not succeed") {
                // First half uploads, second half dies of a server error: the cursor must stop at
                // the midpoint, never at the end of the parent chunk.
                walk { chunk in
                    if chunk.duration >= hour { return .uploadPayloadTooLarge }
                    if chunk.start == cursor + 30 * minute { return .uploadServerError(underlyingError: TestError.generic) }
                    return nil
                }

                expect(storage.uploadStartDate(forDataType: dataType)).to(equal(cursor + 30 * minute))
            }

            it("spends a bounded attempt budget on one chunk and leaves its cursor untouched") {
                // Connectivity errors used to retry the same chunk in an unbounded tight loop.
                walk { $0.start == cursor + hour ? .uploadConnectivityError : nil }

                // The literal, deliberately NOT `Constants.HealthKit.MaxChunkUploadAttempts`:
                // asserting against the constant would move with it and check nothing.
                let retried = attempted.filter { $0.start == cursor + hour }
                expect(retried.count).to(equal(5))
                expect(Constants.HealthKit.MaxChunkUploadAttempts).to(equal(5))
                expect(reachEvents(boundedBy: .attemptsExhausted).count).to(equal(1))
                // Cursor left at the end of the last chunk that DID succeed, so the next
                // sequence retries this one rather than skipping it.
                expect(storage.uploadStartDate(forDataType: dataType)).to(equal(cursor + hour))
            }

            it("leaves a normal-sized chunk alone, and an empty chunk does not truncate the walk") {
                // Every chunk succeeds with nothing to upload — the ordinary case, and the shape
                // of the Apple `&&` hazard: an empty batch must not end the walk.
                walk { _ in nil }

                expect(attempted.map { $0.start }).to(equal([cursor, cursor + hour]))
                expect(attempted.first?.end).to(equal(cursor + hour))
                expect(storage.uploadStartDate(forDataType: dataType)).to(equal(attempted.last?.end))
                expect(reachEvents(boundedBy: .bisected)).to(beEmpty())
                expect(reachEvents(boundedBy: .gaveUp)).to(beEmpty())
                expect(reachEvents(boundedBy: .attemptsExhausted)).to(beEmpty())
            }
        }
    }
}

private enum TestError: Error {
    case generic
}

private final class FakeHealthStorage: HealthSampleUploadManagerStorage, HealthSampleUploaderStorage {

    private let lock = NSLock()
    private var cursors: [HealthDataType: Date] = [:]

    var lastUploadSequenceCompletionDate: Date?
    var lastUploadSequenceStartingDate: Date?
    var pendingUploadDataType: HealthDataType?

    func uploadStartDate(forDataType dataType: HealthDataType) -> Date? {
        return self.lock.locked { self.cursors[dataType] }
    }

    func setUploadStartDate(_ date: Date?, forDataType dataType: HealthDataType) {
        self.lock.locked { self.cursors[dataType] = date }
    }

    func saveLastSampleUploadAnchor<T: NSSecureCoding>(_ anchor: T?, forDataType dateType: HealthDataType) {}

    func loadLastSampleUploadAnchor<T: NSSecureCoding & NSObject>(forDataType dateType: HealthDataType) -> T? {
        return nil
    }
}

private final class FakeHealthReachability: HealthSampleUploadManagerReachability {
    var isCurrentlyReachableForHealthSampleUpload: Bool { return true }
    func getIsReachableForHealthSampleUploadObserver() -> Observable<Bool> { return .empty() }
}

private final class FakeHealthClearance: HealthSampleUploadManagerClearanceDelegate {
    var healthManagerCanRun: Bool = true
    var enrollmentDate: Date?
}

private final class FakeHealthNetwork: HealthSampleUploaderNetworkDelegate {
    func uploadHealthNetworkData(_ healthNetworkData: HealthNetworkData, source: String) -> Single<()> {
        return .just(())
    }
}
