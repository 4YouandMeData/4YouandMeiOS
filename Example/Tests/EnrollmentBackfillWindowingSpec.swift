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
//  - SensorSampleUploadManager.buildWindowPlan(now:boundNow:joinDay:cursor:embargo:)
//      round 7: complete UTC calendar days for EVERY sensor, the one-time migration window from
//      an unaligned cursor, a plan that never depends on the device timezone, the first window
//      never opening before the bound, and an empty plan when the bound has reached the cutoff.
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
//  - ServerClock.record(headerDate:deviceNow:defaults:) / .now(current:defaults:analytics:)
//      FUAM-3964: the offset learnt from the backend's `Date` response header, its throttled
//      persistence, the fallback to the device clock when nothing was ever learnt, the join day
//      holding still through a rollback AND a forward jump, and the repurposed
//      `sensor_data_clock_ahead` divergence diagnostic.
//  - SensorSampleUploadManager.buildWindowPlan(for:now:) / HealthSampleUploadManager.startUpload
//      the FUAM-3964 acceptance test: a device clock in the future cannot plan a window — and so
//      cannot write a cursor — past server time (SensorKitServerTimeCapSpec /
//      HealthBackfillChunkWalkSpec).
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
//  - the newly enabled mappers' `recorded_at` (SensorRecordedAtSpec): the backend's semantic
//      anchor, in the fractional-seconds encoding the sibling `t` key already uses, without
//      moving what the consent gate reads.
//  - SensorKitManager.sensorReader(_:startRecordingFailedWithError:) (SensorRecordingFailureSpec):
//      a failed `startRecording()` becomes `sensor_recording_start_failed`, once per sensor
//      per launch.
//

import Quick
import Nimble
import RxSwift
import SensorKit
import HealthKit
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

            it("falls back to UTC — the partition's fallback — never the device timezone (round 2, F2)") {
                // The consent bound and the window grid must share one day-boundary authority
                // (AC2): a device-tz bound made the join sliver window a function of the handset.
                expect(RepositoryImpl.enrollmentCalendar(userTimeZone: nil).timeZone)
                    .to(equal(TimeZone(identifier: "UTC")))
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

        describe("SensorSampleUploadManager.buildWindowPlan (complete UTC days)") {

            func plan(joinDay: Date?, cursor: Date?, now planningNow: Date = now) -> SensorSampleUploadManager.WindowPlan {
                return SensorSampleUploadManager.buildWindowPlan(now: planningNow,
                                                                 boundNow: planningNow,
                                                                 joinDay: joinDay,
                                                                 cursor: cursor,
                                                                 embargo: embargo)
            }

            func utcMidnight(_ date: Date) -> Date {
                return SensorSampleUploadManager.utcDayStart(date)
            }

            context("the lower bound (unchanged by round 7)") {

                it("opens at the join day when it is within the 365-day cap") {
                    let joinDay = utcMidnight(now.addingTimeInterval(-200 * day))
                    let result = plan(joinDay: joinDay, cursor: nil)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.joinDate))
                    expect(result.lowerBound).to(equal(joinDay))
                    expect(result.windows.first?.start).to(equal(joinDay))
                }

                it("never reaches back beyond the 365-day cap for a join day 500 days ago") {
                    let result = plan(joinDay: now.addingTimeInterval(-500 * day), cursor: nil)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.hardCap365d))
                    expect(result.windows.first?.start).to(equal(now.addingTimeInterval(-hardCap)))
                    for window in result.windows {
                        expect(window.start.timeIntervalSince(now)).to(beGreaterThanOrEqualTo(-hardCap))
                    }
                }

                it("resumes from a cursor ahead of the bound instead of re-uploading") {
                    let cursor = now.addingTimeInterval(-2 * day)
                    let result = plan(joinDay: now.addingTimeInterval(-10 * day), cursor: cursor)
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.cursor))
                    expect(result.lowerBound).to(equal(cursor))
                    expect(result.windows.first?.start).to(equal(cursor))
                }

                it("ignores a stale cursor behind the bound") {
                    let joinDay = utcMidnight(now.addingTimeInterval(-3 * day))
                    let result = plan(joinDay: joinDay, cursor: now.addingTimeInterval(-6 * day))
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.joinDate))
                    expect(result.windows.first?.start).to(equal(joinDay))
                }

                it("returns an empty plan when the bound has reached the embargo cutoff") {
                    let result = plan(joinDay: now.addingTimeInterval(-hour), cursor: nil)
                    expect(result.windows).to(beEmpty())
                }
            }

            context("UTC-day alignment (round 7: one scheme for every sensor)") {

                it("cuts whole UTC days, contiguously, for an aligned bound") {
                    let joinDay = utcMidnight(now.addingTimeInterval(-5 * day))
                    let result = plan(joinDay: joinDay, cursor: nil)
                    expect(result.windows).toNot(beEmpty())
                    for window in result.windows {
                        expect(window.start).to(equal(utcMidnight(window.start)))
                        expect(window.duration).to(equal(day))
                    }
                    for (previous, next) in zip(result.windows, result.windows.dropFirst()) {
                        expect(previous.end).to(equal(next.start))
                    }
                }

                it("plans complete days only: no window ever ends past the embargo cutoff") {
                    let result = plan(joinDay: utcMidnight(now.addingTimeInterval(-10 * day)), cursor: nil)
                    let safeTo = now.addingTimeInterval(-embargo)
                    expect(result.windows.last?.end).to(beLessThanOrEqualTo(safeTo))
                    // The next whole day would overshoot, which is why it is not planned.
                    expect(result.windows.last?.end.addingTimeInterval(day)).to(beGreaterThan(safeTo))
                }

                it("produces the same plan whatever the device timezone is") {
                    // Round 7 removed the `Calendar` from the planner entirely; this is the
                    // regression guard against anyone reintroducing `Calendar.current`.
                    let joinDay = utcMidnight(now.addingTimeInterval(-4 * day)).addingTimeInterval(7 * hour)
                    let original = NSTimeZone.default
                    var plans: [[DateInterval]] = []
                    for identifier in ["UTC", "Asia/Tokyo", "Pacific/Kiritimati", "America/Los_Angeles"] {
                        NSTimeZone.default = TimeZone(identifier: identifier)!
                        plans.append(plan(joinDay: joinDay, cursor: nil).windows)
                    }
                    NSTimeZone.default = original
                    for other in plans.dropFirst() {
                        expect(other).to(equal(plans[0]))
                    }
                }
            }

            context("the one-time migration window") {

                it("emits a single partial window from an unaligned cursor to the next UTC midnight") {
                    let cursor = utcMidnight(now.addingTimeInterval(-4 * day)).addingTimeInterval(15 * hour + 37 * 60)
                    let result = plan(joinDay: now.addingTimeInterval(-30 * day), cursor: cursor)
                    let boundary = utcMidnight(cursor).addingTimeInterval(day)
                    expect(result.windows.first?.start).to(equal(cursor))
                    expect(result.windows.first?.end).to(equal(boundary))
                    // Exactly one partial window: everything after it is a whole UTC day.
                    for window in result.windows.dropFirst() {
                        expect(window.start).to(equal(utcMidnight(window.start)))
                        expect(window.duration).to(equal(day))
                    }
                }

                it("never repeats it: the cursor it leaves behind is UTC-aligned") {
                    let cursor = utcMidnight(now.addingTimeInterval(-4 * day)).addingTimeInterval(15 * hour)
                    let first = plan(joinDay: now.addingTimeInterval(-30 * day), cursor: cursor)
                    // The pipeline advances the cursor to the end of each processed window.
                    guard let lastEnd = first.windows.last?.end else {
                        fail("expected a non-empty first plan")
                        return
                    }
                    let second = plan(joinDay: now.addingTimeInterval(-30 * day), cursor: lastEnd)
                    for window in second.windows {
                        expect(window.start).to(equal(utcMidnight(window.start)))
                        expect(window.duration).to(equal(day))
                    }
                }

                it("waits instead of cutting an incomplete partial window") {
                    // An unaligned cursor inside the UTC day that is not over yet (as far as the
                    // embargo is concerned): the migration sliver [cursor, next midnight) would end
                    // beyond safeTo, so nothing is planned until that day completes.
                    let safeTo = now.addingTimeInterval(-embargo)
                    let cursor = utcMidnight(safeTo).addingTimeInterval(hour)
                    let result = plan(joinDay: now.addingTimeInterval(-30 * day), cursor: cursor)
                    expect(result.windows).to(beEmpty())
                }

                it("cuts the migration sliver exactly once when its day is already complete") {
                    // A cursor at 23:00 of a FINISHED UTC day: the sliver [23:00, midnight) is a
                    // complete, deterministic window — it is planned once and leaves the cursor
                    // UTC-aligned, which is the whole migration.
                    let safeTo = now.addingTimeInterval(-embargo)
                    let cursor = utcMidnight(safeTo).addingTimeInterval(-hour)
                    let result = plan(joinDay: now.addingTimeInterval(-30 * day), cursor: cursor)
                    expect(result.windows.first?.start).to(equal(cursor))
                    expect(result.windows.first?.end).to(equal(utcMidnight(safeTo)))
                }

                it("opens the partial window at the join day, never before it") {
                    let joinDay = utcMidnight(now.addingTimeInterval(-6 * day)).addingTimeInterval(9 * hour)
                    let result = plan(joinDay: joinDay, cursor: nil)
                    expect(result.windows.first?.start).to(equal(joinDay))
                    for window in result.windows {
                        expect(window.start).to(beGreaterThanOrEqualTo(joinDay))
                    }
                }
            }

            context("no resolvable join day (FUAM-3945: forward-only, never a legacy window)") {

                // The host consent-bypass flags (FYAMHealthKitIgnoreOptInConsent /
                // FYAMSensorKitIgnoreOptInConsent) are deliberately NOT inputs to this policy
                // any more — there is no code path left that could widen the bound, hence
                // nothing about them to inject here.
                it("is forward-only: the bound is now and the plan is empty") {
                    let result = plan(joinDay: nil, cursor: nil)
                    expect(result.lowerBound).to(equal(now))
                    expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.forwardOnly))
                    expect(result.windows).to(beEmpty())
                }

                it("does not reopen history from a stale cursor when the join day is unknown") {
                    // A cursor left behind by a previous enrolment must not become a backfill
                    // bound of its own: the window may only open at (or after) `now`.
                    let result = plan(joinDay: nil, cursor: now.addingTimeInterval(-30 * day))
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
                    for sensor in [SRSensor.pedometerData, .deviceUsageReport, .keyboardMetrics, .visits] {
                        let result = SensorSampleUploadManager.dropPreBoundRecords(records,
                                                                                   lowerBound: bound.date,
                                                                                   windowStart: now.addingTimeInterval(-day),
                                                                                   sensor: sensor)
                        expect(result).to(beEmpty())
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

        describe("ServerClock (FUAM-3964: trust the server clock, not the device)") {

            var defaults: UserDefaults!
            var analytics: CapturingAnalyticsService!

            /// An HTTP `Date` header (RFC 7231 IMF-fixdate) for a given instant.
            func header(_ date: Date) -> String {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(identifier: "GMT")
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                return formatter.string(from: date)
            }

            func clockEvents(_ events: [AnalyticsEvent]) -> [(mark: String, deviceNow: String)] {
                return events.compactMap { event in
                    if case let .sensorDataClockAhead(mark, deviceNow) = event { return (mark, deviceNow) }
                    return nil
                }
            }

            beforeEach {
                defaults = UserDefaults(suiteName: "ServerClockSpec.\(UUID().uuidString)")
                analytics = CapturingAnalyticsService()
                ServerClock.resetReportLatchesForTesting()
            }

            context("learning the offset from the Date header") {

                it("persists serverTime - deviceTime") {
                    let deviceNow = now.addingTimeInterval(-2 * day)   // device clock 2 days behind
                    ServerClock.record(headerDate: header(now), deviceNow: deviceNow, defaults: defaults)
                    expect(ServerClock.storedOffset(defaults: defaults)).to(beCloseTo(2 * day, within: 1))
                    expect(ServerClock.now(current: deviceNow, defaults: defaults)).to(beCloseTo(now, within: 1))
                }

                it("falls back to the device clock when no offset was ever stored") {
                    expect(ServerClock.storedOffset(defaults: defaults)).to(beNil())
                    expect(ServerClock.now(current: now, defaults: defaults)).to(equal(now))
                }

                it("ignores a missing or unparsable header, so a stripping proxy cannot move the clock") {
                    ServerClock.record(headerDate: nil, deviceNow: now, defaults: defaults)
                    ServerClock.record(headerDate: "not a date", deviceNow: now, defaults: defaults)
                    ServerClock.record(headerDate: "2026-08-10T12:00:00Z", deviceNow: now, defaults: defaults)
                    expect(ServerClock.storedOffset(defaults: defaults)).to(beNil())
                }

                it("does not rewrite the offset for a sub-threshold change (write throttle)") {
                    let deviceNow = now.addingTimeInterval(-2 * day)
                    ServerClock.record(headerDate: header(now), deviceNow: deviceNow, defaults: defaults)
                    let first = ServerClock.storedOffset(defaults: defaults)
                    // One second of network jitter is not a clock change.
                    ServerClock.record(headerDate: header(now.addingTimeInterval(1)), deviceNow: deviceNow, defaults: defaults)
                    expect(ServerClock.storedOffset(defaults: defaults)).to(equal(first))
                }

                it("rewrites the offset once the change passes the threshold") {
                    let deviceNow = now.addingTimeInterval(-2 * day)
                    ServerClock.record(headerDate: header(now), deviceNow: deviceNow, defaults: defaults)
                    let moved = now.addingTimeInterval(ServerClock.persistenceGranularity + 5)
                    ServerClock.record(headerDate: header(moved), deviceNow: deviceNow, defaults: defaults)
                    expect(ServerClock.storedOffset(defaults: defaults))
                        .to(beCloseTo(moved.timeIntervalSince(deviceNow), within: 1))
                }
            }

            context("the join day no longer moves with the device clock") {

                it("stays put when the device clock is wound BACK 30 days") {
                    // The leak this defends: a rollback used to move the derived join day 30 days
                    // earlier, and the plan and the per-record filter agreed on it.
                    let rolledBack = now.addingTimeInterval(-30 * day)
                    ServerClock.record(headerDate: header(now), deviceNow: rolledBack, defaults: defaults)
                    let honest = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10, now: now, calendar: calendar)
                    let naive = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10, now: rolledBack, calendar: calendar)
                    let defended = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10,
                                                                 now: ServerClock.now(current: rolledBack, defaults: defaults),
                                                                 calendar: calendar)
                    expect(naive).to(beLessThan(honest))
                    expect(defended).to(equal(honest))
                }

                it("stays put when the device clock jumps FORWARD 30 days (which BackfillClock could not do)") {
                    let jumped = now.addingTimeInterval(30 * day)
                    ServerClock.record(headerDate: header(now), deviceNow: jumped, defaults: defaults)
                    let honest = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10, now: now, calendar: calendar)
                    let naive = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10, now: jumped, calendar: calendar)
                    let defended = RepositoryImpl.enrollmentDate(fromDaysInStudy: 10,
                                                                 now: ServerClock.now(current: jumped, defaults: defaults),
                                                                 calendar: calendar)
                    expect(naive).to(beGreaterThan(honest))
                    expect(defended).to(equal(honest))
                }
            }

            context("the divergence diagnostic (the repurposed sensor_data_clock_ahead)") {

                it("reports server time and device time once per launch beyond a day of drift") {
                    let jumped = now.addingTimeInterval(10 * day)
                    ServerClock.record(headerDate: header(now), deviceNow: jumped, defaults: defaults)

                    _ = ServerClock.now(current: jumped, defaults: defaults, analytics: analytics)
                    _ = ServerClock.now(current: jumped, defaults: defaults, analytics: analytics)

                    let reported = clockEvents(analytics.trackedEvents)
                    expect(reported.count).to(equal(1))
                    // `mark` is server now, `device_now` is the device's: the drift is their difference.
                    expect(reported.first?.deviceNow).to(equal(iso(jumped)))
                    expect(reported.first?.mark).toNot(equal(reported.first?.deviceNow))
                }

                it("fires for a device clock BEHIND the server too, not just ahead") {
                    let behind = now.addingTimeInterval(-10 * day)
                    ServerClock.record(headerDate: header(now), deviceNow: behind, defaults: defaults)
                    _ = ServerClock.now(current: behind, defaults: defaults, analytics: analytics)
                    expect(clockEvents(analytics.trackedEvents).count).to(equal(1))
                }

                it("stays silent for less than a day of drift (jitter, not a wrong clock)") {
                    let slightlyOff = now.addingTimeInterval(hour)
                    ServerClock.record(headerDate: header(now), deviceNow: slightlyOff, defaults: defaults)
                    _ = ServerClock.now(current: slightlyOff, defaults: defaults, analytics: analytics)
                    expect(clockEvents(analytics.trackedEvents)).to(beEmpty())
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

        /// FUAM-3945 folded the seven threaded parameters of `handleWindowResult` into one
        /// per-device chain context; these specs drive the single-device (iPhone) chain, which is
        /// exactly the pre-FUAM-3945 shape.
        func context(_ mapper: SensorSampleMapper, _ plannedBound: Date) -> SensorSampleUploadManager.DeviceChainContext {
            let device = SensorDevice(device: nil, key: SensorDevice.iphoneKey, productType: "iPhone17,1", systemVersion: "18.0")
            return SensorSampleUploadManager.DeviceChainContext(sensor: sensor,
                                                                device: device,
                                                                devices: [device],
                                                                deviceIndex: 0,
                                                                now: Date(),
                                                                mapper: mapper,
                                                                plannedBound: plannedBound)
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

        describe("drainQueue (the permanent-rejection budget, FUAM-3945 round 5 / AC6)") {

            func droppedReasons(_ events: [AnalyticsEvent]) -> [String] {
                return events.compactMap { event in
                    if case let .sensorRecordDropped(_, _, reason) = event { return reason }
                    return nil
                }
            }

            it("drops a permanently rejected batch after the budget, reports it, and drains the rest") {
                storage.seed(records: [["t": iso(joinDay.addingTimeInterval(hour)), "marker": "poison"]],
                             windowStart: joinDay,
                             for: sensor)
                storage.enqueueBatch([["t": iso(joinDay.addingTimeInterval(2 * hour)), "marker": "good"]],
                                     windowStart: joinDay,
                                     for: sensor)
                network.errorForPayload = { payload in
                    let isPoison = payload.contains { $0["marker"] as? String == "poison" }
                    return isPoison ? SensorUploadError.permanentlyRejected(statusCode: 422) : nil
                }

                // Drain 1: poison (head) rejected once, re-enqueued at the tail.
                manager.drainQueue(for: sensor)
                expect(network.attemptCount).toEventually(equal(1), timeout: .seconds(5))
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(2), timeout: .seconds(5))

                // Drain 2: good uploads, poison rejected a second time.
                manager.drainQueue(for: sensor)
                expect(network.attemptCount).toEventually(equal(3), timeout: .seconds(5))
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(1), timeout: .seconds(5))

                // Drain 3: the third rejection exhausts the budget — the batch is dropped
                // (NOT re-enqueued), reported, and the drain runs on to the end of the queue.
                manager.drainQueue(for: sensor)
                expect(network.attemptCount).toEventually(equal(4), timeout: .seconds(5))
                expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(0), timeout: .seconds(5))

                expect(network.uploaded.count).to(equal(1))
                expect(network.uploaded.first?.first?["marker"] as? String).to(equal("good"))
                expect(drainOrigins(analytics.trackedEvents)).to(contain("upload_stuck"))
                expect(droppedReasons(analytics.trackedEvents)).to(contain("upload_rejected_422"))
            }

            it("never burns the budget on a transient failure: the batch outlives every retry") {
                storage.seed(records: [["t": iso(joinDay.addingTimeInterval(hour))]],
                             windowStart: joinDay,
                             for: sensor)
                network.errorForPayload = { _ in RepositoryError.connectivityError }

                for drain in 1...5 {
                    manager.drainQueue(for: sensor)
                    expect(network.attemptCount).toEventually(equal(drain), timeout: .seconds(5))
                    expect(storage.pendingBatchCount(for: sensor)).toEventually(equal(1), timeout: .seconds(5))
                }

                expect(drainOrigins(analytics.trackedEvents)).toNot(contain("upload_stuck"))
                expect(droppedReasons(analytics.trackedEvents)).to(beEmpty())
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
                                           context: context(mapper, joinDay))

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
                                           context: context(mapper, joinDay))

                expect(storage.enqueued).to(beEmpty())

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(hour))]]),
                                           window: window,
                                           at: 0,
                                           of: [window],
                                           context: context(mapper, joinDay))

                expect(storage.enqueued.count).toEventually(equal(1))
            }

            it("gates on the re-resolved bound when the refresh moved the join day later") {
                clearance.enrollmentDate = joinDay.addingTimeInterval(7 * day)
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(hour))]]),
                                           window: window,
                                           at: 0,
                                           of: [window],
                                           context: context(mapper, joinDay))

                expect(storage.enqueued).to(beEmpty())
            }

            it("persists the fetch window alongside the batch it enqueues") {
                let window = DateInterval(start: joinDay, end: joinDay.addingTimeInterval(day))

                manager.handleWindowResult(.success([["t": iso(joinDay.addingTimeInterval(hour))]]),
                                           window: window,
                                           at: 0,
                                           of: [window],
                                           context: context(mapper, joinDay))

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
    private var ledgers: [String: [String: SensorLedgerEntry]] = [:]
    private var rescanDays: [String: Date] = [:]
    private var deepestWindows: [String: Date] = [:]

    /// AC4: when `true`, every enqueue reports failure — the persisted-queue write "throws".
    var failEnqueue = false

    /// Every batch ever enqueued, kept even after it is dequeued (audit log for the specs).
    var enqueued: [(records: [[String: Any]], windowStart: Date)] {
        return self.lock.locked { self.enqueuedBatches }
    }

    func seed(records: [[String: Any]], windowStart: Date, for sensor: SRSensor) {
        self.lock.locked { self.queues[sensor.rawValue] = [(records, windowStart)] }
    }

    func lastCursor(for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) -> Date? {
        return self.lock.locked { self.cursors["\(sensor.rawValue).\(deviceKey)"] }
    }

    func setLastCursor(_ date: Date, for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) {
        self.lock.locked { self.cursors["\(sensor.rawValue).\(deviceKey)"] = date }
    }

    @discardableResult
    func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> Bool {
        return self.lock.locked {
            guard !self.failEnqueue else { return false }
            self.queues[sensor.rawValue, default: []].append((batch, windowStart))
            self.enqueuedBatches.append((batch, windowStart))
            return true
        }
    }

    func ledger(for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) -> [String: SensorLedgerEntry] {
        return self.lock.locked { self.ledgers["\(sensor.rawValue).\(deviceKey)"] ?? [:] }
    }

    func setLedger(_ ledger: [String: SensorLedgerEntry], for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) {
        self.lock.locked { self.ledgers["\(sensor.rawValue).\(deviceKey)"] = ledger }
    }

    func purgeLedger(for sensor: SRSensor) {
        self.lock.locked {
            for key in self.ledgers.keys where key.hasPrefix(sensor.rawValue + ".") {
                self.ledgers[key] = nil
            }
        }
    }

    func lastRescanDay(for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) -> Date? {
        return self.lock.locked { self.rescanDays["\(sensor.rawValue).\(deviceKey)"] }
    }

    func setLastRescanDay(_ day: Date, for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) {
        self.lock.locked { self.rescanDays["\(sensor.rawValue).\(deviceKey)"] = day }
    }

    func deepestProductiveWindowStart(for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) -> Date? {
        return self.lock.locked { self.deepestWindows["\(sensor.rawValue).\(deviceKey)"] }
    }

    func setDeepestProductiveWindowStart(_ date: Date, for sensor: SRSensor, deviceKey: String = SensorDevice.iphoneKey) {
        self.lock.locked { self.deepestWindows["\(sensor.rawValue).\(deviceKey)"] = date }
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
    /// UTC by default, so every pre-existing grid assertion stays byte-identical (a UTC
    /// participant gets exactly the round-7 grid); tz-specific specs override it.
    var participantTimeZone: TimeZone? = TimeZone(identifier: "UTC")
}

private final class FakeSensorMapper: SensorSampleMapper {
    private let lock = NSLock()
    private var fetched: [DateInterval] = []

    var windows: [DateInterval] { return self.lock.locked { self.fetched } }

    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        self.lock.locked { self.fetched.append(DateInterval(start: from, end: to)) }
        completion(.success([]))
    }
}

private final class FakeSensorNetwork: SensorSampleUploaderNetworkDelegate {
    private let lock = NSLock()
    private var payloads: [[[String: Any]]] = []
    private var attempts = 0

    /// When set, decides the outcome per payload (round 5): a non-nil error fails that upload.
    var errorForPayload: (([[String: Any]]) -> Error?)?

    /// Successful uploads only.
    var uploaded: [[[String: Any]]] { return self.lock.locked { self.payloads } }
    /// Every upload attempt, successful or not.
    var attemptCount: Int { return self.lock.locked { self.attempts } }

    func uploadSensorBatch(sensor: SRSensor, payload: [[String: Any]]) -> Single<Void> {
        self.lock.locked { self.attempts += 1 }
        if let error = self.errorForPayload?(payload) { return .error(error) }
        self.lock.locked { self.payloads.append(payload) }
        return .just(())
    }
}

// MARK: - FUAM-3964: a RECORDED clock offset caps the plan at server time

/// The acceptance test for the server-time cap on the SensorKit side, **conditional on an offset
/// having been recorded** — which is the whole extent of the protection (review I2). The device
/// clock is days ahead of the server's AND a response has been observed under that wrong clock,
/// so `ServerClock.storageKey` holds the offset; every window the planner opens must then end at
/// or before `serverNow - embargo`, because the pipeline advances the cursor to the end of each
/// window it processes. Without the cap the plan runs to `deviceNow - embargo`, the cursor is
/// burned there, and correcting the clock leaves a hole no plan can ever reopen (the cursor only
/// moves forward).
///
/// What is deliberately NOT covered, because it is not implemented and will not be: a device
/// whose clock moves while it is offline. With no offset stored (or one recorded before the clock
/// moved) `ServerClock.now()` is just `Date()` and planning, fetching, enqueuing and the cursor
/// write all proceed uncapped until the first response afterwards. Gating collection on recent
/// server contact would punish every participant in a tunnel to protect a rare one with a wrong
/// clock, so that offline excursion is the accepted residual — see the last example below, which
/// pins the uncapped behaviour rather than asserting protection.
///
/// This drives `buildWindowPlan(for:now:device:)` — the outermost reachable seam.
/// `fetchPendingWindows` cannot be used: no SensorKit sensor is ever `.authorized` on the
/// simulator, so it returns before planning anything.
class SensorKitServerTimeCapSpec: QuickSpec {

    override class func spec() {

        let day: TimeInterval = 24 * 3600
        let embargo: TimeInterval = day
        let sensor = SRSensor.pedometerData
        let clockSkew: TimeInterval = 5 * day

        var storage: FakeSensorStorage!
        var clearance: FakeSensorClearance!
        var analytics: CapturingAnalyticsService!
        var manager: SensorSampleUploadManager!
        var deviceNow: Date!
        var serverNow: Date!

        beforeEach {
            // The device clock is `clockSkew` AHEAD of the server's.
            deviceNow = Date()
            serverNow = deviceNow.addingTimeInterval(-clockSkew)
            UserDefaults.standard.set(-clockSkew, forKey: ServerClock.storageKey)

            storage = FakeSensorStorage()
            clearance = FakeSensorClearance()
            analytics = CapturingAnalyticsService()
            clearance.enrollmentDate = serverNow.addingTimeInterval(-30 * day)
            manager = SensorSampleUploadManager(withSensors: [sensor],
                                                storage: storage,
                                                reachability: FakeSensorReachability(),
                                                analytics: analytics,
                                                mappers: [sensor: FakeSensorMapper()])
            manager.clearanceDelegate = clearance
        }

        afterEach {
            UserDefaults.standard.removeObject(forKey: ServerClock.storageKey)
        }

        it("never plans past server time once an offset has been recorded under the wrong clock") {
            let plan = manager.buildWindowPlan(for: sensor, now: deviceNow, device: .current)
            expect(plan.windows).toNot(beEmpty())
            guard let last = plan.windows.last else { return }
            // The cursor lands on `last.end`: that is the value that must not escape.
            expect(last.end).to(beLessThanOrEqualTo(serverNow.addingTimeInterval(-embargo)))
            expect(last.end).to(beLessThan(deviceNow.addingTimeInterval(-embargo)))
        }

        it("resets a cursor a wrong clock burnt into the future, and reports the gap") {
            // Worst case: a previous cycle (offline, before any offset was recorded) burned the
            // cursor to device time. Parking on it — the pre-F1 behaviour — meant the interval
            // between the excursion and the cursor was never fetched: the plan stayed empty until
            // real time passed the cursor and then resumed AT it.
            let burned = deviceNow.addingTimeInterval(-2 * day)   // > 1 day above the capped bound
            storage.setLastCursor(burned, for: sensor)

            let plan = manager.buildWindowPlan(for: sensor, now: deviceNow, device: .current)

            // The plan reopens at the consent bound, not at the burnt cursor.
            expect(plan.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.futureCursor))
            expect(plan.lowerBound).to(equal(plan.consentBound))
            expect(plan.windows.first?.start).to(equal(plan.consentBound))
        }

        it("rewinds the stored cursor and emits future_cursor carrying the corrupt value") {
            let burned = deviceNow.addingTimeInterval(-2 * day)
            storage.setLastCursor(burned, for: sensor)

            manager.runDeviceChain(at: 0,
                                   of: [.current],
                                   for: sensor,
                                   now: deviceNow,
                                   using: FakeSensorMapper())

            let reported: [(String, String)] = analytics.trackedEvents.compactMap { event in
                guard case let .sensorDataBackfillReach(_, reachedBack, boundedBy) = event,
                      boundedBy == BackfillLowerBound.Origin.futureCursor.rawValue else { return nil }
                return (reachedBack, boundedBy)
            }
            expect(reported).to(haveCount(1))
            expect(reported.first?.0).to(equal(ISO8601DateFormatter().string(from: burned)))
            // The rewind actually happened: the stored cursor is no longer in the future.
            expect(storage.lastCursor(for: sensor))
                .toEventually(beLessThan(deviceNow.addingTimeInterval(-day)), timeout: .seconds(5))
        }

        it("leaves a cursor at the head of the last complete day alone (tolerance)") {
            // A legitimate cursor sits at most one embargo behind the capped upper bound; the
            // one-UTC-day tolerance must not turn that into a reset (which would re-fetch a day
            // on every single cycle).
            let legitimate = serverNow.addingTimeInterval(-embargo - 60)
            storage.setLastCursor(legitimate, for: sensor)
            let plan = manager.buildWindowPlan(for: sensor, now: deviceNow, device: .current)
            expect(plan.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.cursor))
        }

        it("plans on the device clock alone when no offset was ever recorded (accepted residual)") {
            // This is BOTH the "clock is fine, don't get in the way" case and the honest statement
            // of the limit: with nothing stored there is no cap at all, so an offline device with
            // a wrong clock plans, fetches, enqueues and writes its cursor uncapped (review I2).
            UserDefaults.standard.removeObject(forKey: ServerClock.storageKey)
            let plan = manager.buildWindowPlan(for: sensor, now: deviceNow, device: .current)
            expect(plan.windows).toNot(beEmpty())
            expect(plan.windows.last?.end).to(beGreaterThan(serverNow.addingTimeInterval(-embargo)))
        }

        it("measures the 365-day hard cap from the LATER clock, so a rolled-back clock cannot widen it") {
            // Device clock rolled BACK 5 days relative to the server (offset positive). A hard cap
            // resolved on the raw device clock would reach `deviceNow - 365d` = 370 real days back;
            // `max(deviceNow, serverNow)` keeps it at `serverNow - 365d` (review I1).
            let rolledBack = Date()
            let realNow = rolledBack.addingTimeInterval(clockSkew)
            UserDefaults.standard.set(clockSkew, forKey: ServerClock.storageKey)
            clearance.enrollmentDate = realNow.addingTimeInterval(-500 * day)   // well past the cap
            let plan = manager.buildWindowPlan(for: sensor, now: rolledBack, device: .current)
            expect(plan.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.hardCap365d))
            expect(plan.consentBound).to(beCloseTo(realNow.addingTimeInterval(-365 * day), within: 2))
            expect(plan.consentBound).to(beGreaterThan(rolledBack.addingTimeInterval(-365 * day)))
        }
    }
}

// MARK: - FUAM-3945 round 7: `recorded_at` on the newly enabled sensors

/// `SRFetchResult` cannot be constructed outside SensorKit, so the mappers' record shape is
/// exercised through their (internal) KVC mapping functions, with a KVC-compliant stand-in for
/// the sample object. What matters and is asserted here:
/// 1. `recorded_at` is present — the backend's semantic anchor reads
///    `min(records[].recorded_at)` and silently falls back to UPLOAD time without it, which
///    destroys de-duplication (FUAM-4013);
/// 2. it is encoded exactly like the `t` key sitting next to it (`ISO8601Strategy`, fractional
///    seconds, explicit `Z` — the backend parses strictly and requires an offset);
/// 3. it does NOT become the measurement time the consent gate reads.
class SensorRecordedAtSpec: QuickSpec {

    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        // 2026-08-10 12:00:00.500 UTC — deliberately not on a whole second.
        let recordedAt = Date(timeIntervalSince1970: 1786363200.5)
        let measuredAt = Date(timeIntervalSince1970: 1786100000.25)
        let recordedAtISO = ISO8601Strategy.encode(recordedAt)

        it("encodes with fractional seconds and an explicit offset, like the sibling `t` key") {
            expect(recordedAtISO).to(equal("2026-08-10T12:00:00.500Z"))
        }

        it("puts recorded_at on an ambient light record without touching `t`") {
            let sample = FakeAmbientLightSample(timestamp: measuredAt, lux: 42)
            let record = AmbientLightMapper.mapAmbientLight(sample, recordedAtISO: recordedAtISO)
            expect(record?["recorded_at"] as? String).to(equal(recordedAtISO))
            expect(record?["t"] as? String).to(equal(ISO8601Strategy.encode(measuredAt)))
        }

        it("puts recorded_at on an ambient pressure record without touching `t`") {
            let sample = FakeAmbientPressureSample(timestamp: measuredAt, pressure: 101.3)
            let record = AmbientPressureMapper.mapAmbientPressure(sample, recordedAtISO: recordedAtISO)
            expect(record?["recorded_at"] as? String).to(equal(recordedAtISO))
            expect(record?["t"] as? String).to(equal(ISO8601Strategy.encode(measuredAt)))
        }

        it("puts recorded_at on a rotation rate record even though the sensor stays disabled") {
            // Unit level only: `.rotationRate` has no mapper registered in `Services`. Emitting
            // the anchor now is what makes a future enable a backend-side no-op.
            let sample = FakeRotationRateSample(timestamp: measuredAt)
            let record = RotationRateMapper.mapRotationSample(sample, recordedAtISO: recordedAtISO)
            expect(record?["recorded_at"] as? String).to(equal(recordedAtISO))
            expect(record?["t"] as? String).to(equal(ISO8601Strategy.encode(measuredAt)))
        }

        context("the consent gate still reads the MEASUREMENT time, not the new key") {

            let bound = Date(timeIntervalSince1970: 1786104000)   // 2026-08-10 12:00:00 UTC

            func pedometerRecord(startedAt: Date) -> [String: Any] {
                // The shape PedometerMapper emits: epoch-ms measurement window + the write time.
                return ["start_ms": Int(startedAt.timeIntervalSince1970 * 1000),
                        "end_ms": Int(startedAt.addingTimeInterval(60).timeIntervalSince1970 * 1000),
                        "steps": 120,
                        "recorded_at": ISO8601Strategy.encode(bound.addingTimeInterval(hour))]
            }

            it("drops a pedometer sample measured before the bound although it was WRITTEN after it") {
                let record = pedometerRecord(startedAt: bound.addingTimeInterval(-day))
                let kept = SensorSampleUploadManager.dropPreBoundRecords([record],
                                                                         lowerBound: bound,
                                                                         windowStart: bound,
                                                                         sensor: .pedometerData)
                expect(kept).to(beEmpty())
            }

            it("keeps a pedometer sample measured after the bound") {
                let record = pedometerRecord(startedAt: bound.addingTimeInterval(hour))
                let kept = SensorSampleUploadManager.dropPreBoundRecords([record],
                                                                         lowerBound: bound,
                                                                         windowStart: bound,
                                                                         sensor: .pedometerData)
                expect(kept.count).to(equal(1))
            }

            it("drops an ambient sample measured before the bound although it was WRITTEN after it") {
                let record: [String: Any] = ["t": ISO8601Strategy.encode(bound.addingTimeInterval(-hour)),
                                             "lux": 12.0,
                                             "recorded_at": ISO8601Strategy.encode(bound.addingTimeInterval(hour))]
                let kept = SensorSampleUploadManager.dropPreBoundRecords([record],
                                                                         lowerBound: bound,
                                                                         windowStart: bound,
                                                                         sensor: .ambientLightSensor)
                expect(kept).to(beEmpty())
            }

            it("treats the newly enabled sensors as continuous, so their window vouches at the bound") {
                for sensor in [SRSensor.pedometerData, .ambientLightSensor, .ambientPressure, .rotationRate] {
                    expect(SensorSampleUploadManager.windowVouches(for: sensor,
                                                                   windowStart: bound,
                                                                   lowerBound: bound)).to(beTrue())
                }
            }
        }
    }
}

/// KVC stand-ins for the SensorKit sample objects, which cannot be instantiated. The mappers read
/// them with `value(forKey:)`, so an `@objc` property of the right name is all they need.
private final class FakeAmbientLightSample: NSObject {
    @objc let startDate: Date
    @objc let lux: Double
    init(timestamp: Date, lux: Double) {
        self.startDate = timestamp
        self.lux = lux
    }
}

private final class FakeAmbientPressureSample: NSObject {
    @objc let timestamp: Date
    @objc let pressure: NSNumber
    init(timestamp: Date, pressure: Double) {
        self.timestamp = timestamp
        self.pressure = NSNumber(value: pressure)
    }
}

private final class FakeRotationRateSample: NSObject {
    @objc let startDate: Date
    // These mirror CMRotationRate's KVC keys verbatim.
    // swiftlint:disable identifier_name
    @objc let x: Double = 0.1
    @objc let y: Double = 0.2
    @objc let z: Double = 0.3
    // swiftlint:enable identifier_name
    init(timestamp: Date) {
        self.startDate = timestamp
    }
}

// MARK: - FUAM-3945 round 7 (F3): a failed startRecording() is no longer silent

/// `ensureRecordingStarted()` used to call `startRecording()` on readers with no delegate, so
/// `sensorReader(_:startRecordingFailedWithError:)` was never delivered and a sensor that never
/// started looked exactly like a sensor with no data. The manager is now the readers' delegate;
/// these specs drive that callback directly (the OS side cannot be provoked on a simulator).
class SensorRecordingFailureSpec: QuickSpec {

    override class func spec() {

        var analytics: CapturingAnalyticsService!
        var manager: SensorKitManager!

        func failures(_ events: [AnalyticsEvent]) -> [(sensor: String, error: String)] {
            return events.compactMap { event in
                if case let .sensorRecordingStartFailed(sensor, error) = event { return (sensor, error) }
                return nil
            }
        }

        beforeEach {
            analytics = CapturingAnalyticsService()
            manager = SensorKitManager(withReadSensors: [.pedometerData, .ambientLightSensor],
                                       analyticsService: analytics,
                                       storage: FakeSensorStorage(),
                                       reachability: FakeSensorReachability(),
                                       mappers: [:])
        }

        it("reports the sensor and the error domain/code, never the localized description") {
            let error = NSError(domain: "SRErrorDomain", code: 8, userInfo: [NSLocalizedDescriptionKey: "localized"])
            manager.sensorReader(SRSensorReader(sensor: .pedometerData), startRecordingFailedWithError: error)

            let reported = failures(analytics.trackedEvents)
            expect(reported.count).to(equal(1))
            expect(reported.first?.sensor).to(equal(SRSensor.pedometerData.shortSubsource))
            expect(reported.first?.error).to(equal("SRErrorDomain/8"))
            expect(reported.first?.error).toNot(contain("localized"))
        }

        it("reports each sensor once per launch, however often the retry loop runs") {
            let error = NSError(domain: "SRErrorDomain", code: 8)
            for _ in 0..<5 {
                manager.sensorReader(SRSensorReader(sensor: .pedometerData), startRecordingFailedWithError: error)
                manager.sensorReader(SRSensorReader(sensor: .ambientLightSensor), startRecordingFailedWithError: error)
            }

            let reported = failures(analytics.trackedEvents)
            expect(reported.count).to(equal(2))
            expect(Set(reported.map { $0.sensor }))
                .to(equal([SRSensor.pedometerData.shortSubsource, SRSensor.ambientLightSensor.shortSubsource]))
        }
    }
}

// MARK: - The HealthKit chunk walk under a future bound (FUAM-3945 review round 4, I2)

/// The backfill bound can land in the FUTURE: a stale `days_in_study` read under a device clock
/// that was ahead, or a join day that simply has not been reached yet on this device's calendar.
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
            // Epoch-hour-aligned, 2–3 hours back: chunks end ONLY on grid boundaries (F3 —
            // never at wall-clock `now`), so an aligned cursor two full hours back yields
            // exactly two whole chunks, [cursor, cursor+1h) and [cursor+1h, cursor+2h), with
            // the incomplete head hour deliberately left for the next sequence.
            var cursor: Date!
            var attempted: [DateInterval]!

            beforeEach {
                clearance.enrollmentDate = Date().addingTimeInterval(-10 * day)
                let nowEpoch = Date().timeIntervalSince1970
                cursor = Date(timeIntervalSince1970: ((nowEpoch / hour).rounded(.down) - 2) * hour)
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
                manager.uploadChunk = { _, chunk, _ in
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
                walk { $0.duration >= hour && $0.start == cursor ? .uploadPayloadTooLarge : nil }

                // The 1-hour chunk, then its two halves in chronological order, then the second
                // whole hour — every boundary on the grid (F3), so all four are asserted exactly.
                let half: Date = cursor + 30 * minute
                let first: Date = cursor + hour
                let second: Date = cursor + 2 * hour
                let expectedStarts: [Date] = [cursor, cursor, half, first]
                let expectedEnds: [Date] = [first, half, first, second]
                expect(attempted.map { $0.start }).to(equal(expectedStarts))
                expect(attempted.map { $0.end }).to(equal(expectedEnds))
                // Nothing was forfeited, and the walk ran to the last complete grid unit.
                expect(reachEvents(boundedBy: .gaveUp)).to(beEmpty())
                expect(reachEvents(boundedBy: .bisected).count).to(equal(1))
                expect(storage.uploadStartDate(forDataType: dataType)).to(equal(attempted.last?.end))
            }

            it("never cuts a chunk at wall-clock now: the incomplete head hour waits (F3)") {
                walk { _ in nil }

                for chunk in attempted {
                    expect(chunk.end.timeIntervalSince1970.truncatingRemainder(dividingBy: hour)).to(equal(0))
                }
                expect(attempted.last?.end).to(equal(cursor + 2 * hour))
                expect(storage.uploadStartDate(forDataType: dataType)).to(equal(cursor + 2 * hour))
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

            it("never walks — nor writes a cursor — past server time (FUAM-3964)") {
                // The device clock is 5 days AHEAD of the server's. `endDate` is capped at server
                // time, so nothing can be queried — nor a cursor written — above it. A cursor
                // sitting more than a day above that cap was written by an earlier, uncapped cycle
                // under the wrong clock: F1 resets it to the consent bound and re-walks, because
                // parking on it (the pre-F1 behaviour) meant the interval between the excursion
                // and the cursor was never fetched at all.
                UserDefaults.standard.set(-5 * day, forKey: ServerClock.storageKey)
                defer { UserDefaults.standard.removeObject(forKey: ServerClock.storageKey) }
                let burned = Date().addingTimeInterval(-2 * day)   // 3 days above the capped end
                storage.setUploadStartDate(burned, forDataType: dataType)

                walk { _ in nil }

                // Sampled AFTER the walk: the cap is `min(Date(), ServerClock.now())` read inside
                // it, so a value read before would be milliseconds earlier and fail spuriously.
                let serverNow = Date().addingTimeInterval(-5 * day)

                expect(reachEvents(boundedBy: .futureCursor)).to(equal([ISO8601DateFormatter().string(from: burned)]))
                expect(attempted).toNot(beEmpty())
                // Still capped: neither the walk nor the cursor may pass server time.
                expect(attempted.last?.end).to(beLessThanOrEqualTo(serverNow))
                expect(storage.uploadStartDate(forDataType: dataType)).to(beLessThanOrEqualTo(serverNow))
                expect(storage.pendingUploadDataType).to(beNil())
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
    /// UTC by default: deterministic day boundaries for the chunk-walk specs.
    var participantTimeZone: TimeZone? = TimeZone(identifier: "UTC")
}

private final class FakeHealthNetwork: HealthSampleUploaderNetworkDelegate {
    func uploadHealthNetworkData(_ healthNetworkData: HealthNetworkData, source: String) -> Single<()> {
        return .just(())
    }
}

// MARK: - FUAM-3945: per-device fetching (iPhone + paired Apple Watch)

/// SensorKit stores iPhone and paired-Watch data separately and a fetch request targets exactly
/// one device, so before this change the Watch stream was unreachable. The invariants these specs
/// defend:
///
/// 1. device identity is by KIND, never by instance (`SRDevice` has no stable id);
/// 2. the iPhone keeps the LEGACY, unsuffixed cursor key — the whole migration, and what makes a
///    rollback to an older build safe — while other kinds are suffixed and advance independently;
/// 3. the watch upper bound is held back 48h (its sync cadence is undocumented) and is still
///    snapped to complete UTC days;
/// 4. per-device chains run strictly sequentially (four of the eleven mappers `precondition` on a
///    concurrent fetch, i.e. crash) and a failing device chain never costs another device its
///    windows;
/// 5. with nothing enumerated the pipeline behaves exactly as it did before FUAM-3945.
class SensorKitPerDeviceSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let day: TimeInterval = 24 * 3600
        let sensor = SRSensor.pedometerData

        /// A UTC midnight at or before real "now", so `min(now, ServerClock.now())` is `now` and
        /// every planned boundary is exact.
        let now = SensorSampleUploadManager.utcDayStart(Date())

        let iphone = SensorDevice(device: nil, key: SensorDevice.iphoneKey,
                                  productType: "iPhone17,1", systemVersion: "18.0")
        let watch = SensorDevice(device: nil, key: SensorDevice.watchKey,
                                 productType: "Watch7,2", systemVersion: "11.2")

        var storage: FakeSensorStorage!
        var clearance: FakeSensorClearance!
        var analytics: CapturingAnalyticsService!
        var mapper: RecordingDeviceMapper!
        var manager: SensorSampleUploadManager!

        func makeManager(joinDay: Date) {
            storage = FakeSensorStorage()
            clearance = FakeSensorClearance()
            clearance.enrollmentDate = joinDay
            analytics = CapturingAnalyticsService()
            mapper = RecordingDeviceMapper()
            manager = SensorSampleUploadManager(withSensors: [sensor],
                                                storage: storage,
                                                reachability: FakeSensorReachability(),
                                                analytics: analytics,
                                                mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance
        }

        beforeEach { makeManager(joinDay: now.addingTimeInterval(-10 * day)) }

        describe("SensorDevice.key (identity by kind, never by instance)") {

            it("calls a paired Apple Watch a watch, from systemName alone") {
                // systemName is the discriminator BELOW iOS 17, where `SRDevice.productType`
                // does not exist at all — our deployment floor is 15.6.
                expect(SensorDevice.key(productType: "", systemName: "watchOS")).to(equal("watch"))
            }

            it("still calls it a watch when only the product type is readable") {
                expect(SensorDevice.key(productType: "Watch7,2", systemName: "")).to(equal("watch"))
            }

            it("calls the phone an iphone") {
                expect(SensorDevice.key(productType: "iPhone17,1", systemName: "iOS")).to(equal("iphone"))
            }

            it("gives an unknown platform a stable, key-safe fallback instead of an empty string") {
                expect(SensorDevice.key(productType: "", systemName: "iPadOS 18")).to(equal("ipados18"))
                expect(SensorDevice.key(productType: "", systemName: "")).to(equal("unknown"))
            }

            it("keys a Watch upgrade to the same kind, so it inherits the watch cursor") {
                expect(SensorDevice.key(productType: "Watch6,1", systemName: "watchOS"))
                    .to(equal(SensorDevice.key(productType: "Watch7,2", systemName: "watchOS")))
            }
        }

        describe("cursor storage keys (zero-migration, rollback-safe)") {

            let defaults = UserDefaults.standard
            let legacyKey = "sensorkit.cursor." + sensor.rawValue
            let watchKey = "sensorkit.cursor." + sensor.rawValue + ".watch"
            // The key the iPhone must NEVER use — cleared too, so a sibling spec cannot leave a
            // value behind that makes the legacy-key assertions pass for the wrong reason.
            let suffixedIphoneKey = "sensorkit.cursor." + sensor.rawValue + ".iphone"
            var realStorage: DefaultsSensorStorage!

            beforeEach {
                defaults.removeObject(forKey: legacyKey)
                defaults.removeObject(forKey: watchKey)
                defaults.removeObject(forKey: suffixedIphoneKey)
                realStorage = DefaultsSensorStorage()
            }
            afterEach {
                defaults.removeObject(forKey: legacyKey)
                defaults.removeObject(forKey: watchKey)
                defaults.removeObject(forKey: suffixedIphoneKey)
            }

            it("writes the iPhone cursor to the byte-identical LEGACY key an older build reads") {
                let date = Date(timeIntervalSince1970: 1_700_000_000)
                realStorage.setLastCursor(date, for: sensor, deviceKey: SensorDevice.iphoneKey)
                // The literal key string is the contract with every build ever shipped.
                expect(defaults.object(forKey: legacyKey) as? Date).to(equal(date))
                expect(defaults.object(forKey: watchKey)).to(beNil())
            }

            it("suffixes every other device kind, leaving the legacy key alone") {
                let date = Date(timeIntervalSince1970: 1_700_000_000)
                realStorage.setLastCursor(date, for: sensor, deviceKey: SensorDevice.watchKey)
                expect(defaults.object(forKey: watchKey) as? Date).to(equal(date))
                expect(defaults.object(forKey: legacyKey)).to(beNil())
            }

            it("keeps the two cursors independent") {
                let iphoneDate = Date(timeIntervalSince1970: 1_700_000_000)
                let watchDate = Date(timeIntervalSince1970: 1_600_000_000)
                realStorage.setLastCursor(iphoneDate, for: sensor, deviceKey: SensorDevice.iphoneKey)
                realStorage.setLastCursor(watchDate, for: sensor, deviceKey: SensorDevice.watchKey)
                expect(realStorage.lastCursor(for: sensor, deviceKey: SensorDevice.iphoneKey)).to(equal(iphoneDate))
                expect(realStorage.lastCursor(for: sensor, deviceKey: SensorDevice.watchKey)).to(equal(watchDate))
            }

            it("reads a cursor written by a pre-FUAM-3945 build as the iPhone cursor") {
                let legacy = Date(timeIntervalSince1970: 1_700_000_000)
                defaults.set(legacy, forKey: legacyKey)
                expect(realStorage.lastCursor(for: sensor, deviceKey: SensorDevice.iphoneKey)).to(equal(legacy))
                // A device kind never seen before starts from nothing and backfills.
                expect(realStorage.lastCursor(for: sensor, deviceKey: SensorDevice.watchKey)).to(beNil())
            }
        }

        describe("the watch holdback") {

            it("holds the watch upper bound back 48h while the iPhone keeps its 24h embargo") {
                let iphonePlan = manager.buildWindowPlan(for: sensor, now: now, device: iphone)
                let watchPlan = manager.buildWindowPlan(for: sensor, now: now, device: watch)
                // `now` is a UTC midnight, so both bounds land exactly on a day boundary.
                expect(iphonePlan.windows.last?.end).to(equal(now.addingTimeInterval(-day)))
                expect(watchPlan.windows.last?.end).to(equal(now.addingTimeInterval(-2 * day)))
            }

            it("still snaps the watch plan to complete UTC days") {
                let watchPlan = manager.buildWindowPlan(for: sensor, now: now, device: watch)
                expect(watchPlan.windows).toNot(beEmpty())
                for window in watchPlan.windows {
                    expect(window.start).to(equal(SensorSampleUploadManager.utcDayStart(window.start)))
                    expect(window.duration).to(equal(day))
                }
            }

            it("plans nothing for the watch when the holdback swallows the only available day") {
                // Join day two UTC days back: the iPhone can complete [-2d, -1d), the watch cannot
                // complete anything yet.
                makeManager(joinDay: now.addingTimeInterval(-2 * day))
                expect(manager.buildWindowPlan(for: sensor, now: now, device: iphone).windows.count).to(equal(1))
                expect(manager.buildWindowPlan(for: sensor, now: now, device: watch).windows).to(beEmpty())
            }

            it("leaves the iPhone plan identical to the pre-FUAM-3945 one") {
                // The holdback SUBSUMES the embargo (`max`, not `+`): the iPhone's 0h holdback
                // must not shorten its plan by a single day.
                let plan = manager.buildWindowPlan(for: sensor, now: now, device: iphone)
                let reference = SensorSampleUploadManager.buildWindowPlan(now: now,
                                                                         boundNow: now,
                                                                         joinDay: clearance.enrollmentDate,
                                                                         cursor: nil,
                                                                         embargo: day)
                expect(plan.windows).to(equal(reference.windows))
            }
        }

        describe("the per-device chain") {

            it("walks every device sequentially, one fetch at a time, and never interleaves them") {
                manager.runDeviceChain(at: 0, of: [iphone, watch], for: sensor, now: now, using: mapper)

                // A fresh install is a BACKFILL: each device probes newest-first and stops after
                // `probeEmptyWindowStop` consecutive confirmed-empty windows (AC1) — the mapper
                // returns nothing, so each device costs exactly that many fetches.
                let perDevice = SensorSampleUploadManager.probeEmptyWindowStop
                expect(mapper.calls.count).toEventually(equal(2 * perDevice), timeout: .seconds(5))
                // The iPhone's probe first, then the watch's — in that order.
                expect(Set(mapper.calls.prefix(perDevice).map { $0.deviceKey })).to(equal(["iphone"]))
                expect(Set(mapper.calls.suffix(perDevice).map { $0.deviceKey })).to(equal(["watch"]))
                // Interleaving WITHIN one chain is structural — `processWindow` only issues the
                // next fetch from the previous one's completion — so the ordering above is the
                // whole assertion. Interleaving BETWEEN two sync cycles is the real hazard and
                // needs a mapper that actually holds its completion: see the C1 block below.
            }

            it("advances each device's cursor independently, the iPhone's on the legacy key") {
                manager.runDeviceChain(at: 0, of: [iphone, watch], for: sensor, now: now, using: mapper)

                expect(storage.lastCursor(for: sensor, deviceKey: "watch"))
                    .toEventually(equal(now.addingTimeInterval(-2 * day)), timeout: .seconds(5))
                expect(storage.lastCursor(for: sensor, deviceKey: "iphone")).to(equal(now.addingTimeInterval(-day)))
            }

            it("tags every uploaded record with the device it came from") {
                mapper.records = [["t": ISO8601DateFormatter().string(from: now.addingTimeInterval(-5 * day))]]
                manager.runDeviceChain(at: 0, of: [watch], for: sensor, now: now, using: mapper)

                expect(storage.enqueued.count).toEventually(beGreaterThan(0), timeout: .seconds(5))
                let record = storage.enqueued.first?.records.first
                expect(record?["device_kind"] as? String).to(equal("watch"))
                expect(record?["device_product_type"] as? String).to(equal("Watch7,2"))
                expect(record?["device_os_version"] as? String).to(equal("11.2"))
            }

            it("suffixes the backfill_reach telemetry for the watch and leaves the iPhone series bare") {
                manager.runDeviceChain(at: 0, of: [iphone, watch], for: sensor, now: now, using: mapper)

                expect(analytics.trackedEvents.count).toEventually(beGreaterThan(1), timeout: .seconds(5))
                let sensors: [String] = analytics.trackedEvents.compactMap { event in
                    if case let .sensorDataBackfillReach(name, _, _) = event { return name }
                    return nil
                }
                expect(sensors).to(contain(sensor.shortSubsource))
                expect(sensors).to(contain("\(sensor.shortSubsource).watch"))
            }
        }

        // MARK: - review C1: two sync cycles must never share a mapper

        /// `syncAllSensors` releases `syncLock` as soon as it has kicked off each sensor's chain,
        /// and the reachability trigger bypasses the sync throttle outright, so a second cycle
        /// could re-enter `runDeviceChain` while the first was still parked inside `fetchAndMap`.
        /// Eight mappers answered `.busy`; the three newly enabled ones (`pedometerData`,
        /// `ambientLightSensor`, `ambientPressure`) hit a `precondition`, i.e. crashed in Release.
        ///
        /// These examples need a mapper that HOLDS its completion — with a synchronous fake the
        /// chain has always unwound before the second cycle starts, which is exactly why the
        /// previous `sawConcurrentFetch` assertion could never fail.
        describe("concurrent sync cycles") {

            it("skips a sensor whose chain is mid-fetch instead of re-entering its mapper") {
                let blocking = BlockingDeviceMapper()
                manager.runDeviceChain(at: 0, of: [iphone], for: sensor, now: now, using: blocking)
                // Parked in the first fetch: the completion is held, so the chain cannot advance.
                expect(blocking.callCount).toEventually(equal(1), timeout: .seconds(5))

                // A second cycle arrives (reachability_up, which the throttle does not stop).
                manager.runDeviceChain(at: 0, of: [iphone], for: sensor, now: now, using: blocking)

                // The in-flight guard turns the crash into a skip: no second `fetchAndMap`.
                expect(blocking.callCount).toAlways(equal(1), until: .milliseconds(300))
                // And a skip is NOT a fetch failure — it must burn none of the give-up budget, or
                // a burst of cycles would advance the cursor over windows that were never read.
                expect(manager.windowFetchFailureCount(for: sensor, deviceKey: iphone.key)).to(equal(0))
            }

            it("releases the guard when the chain reaches its end, so the next cycle plans again") {
                let perProbe = SensorSampleUploadManager.probeEmptyWindowStop
                manager.runDeviceChain(at: 0, of: [iphone], for: sensor, now: now, using: mapper)
                expect(mapper.calls.count).toEventually(equal(perProbe), timeout: .seconds(5))

                // Rewind the cursor to the join day so the next cycle re-probes the same plan:
                // the only thing that can stop it now is a guard the finished chain failed to
                // release.
                storage.setLastCursor(now.addingTimeInterval(-10 * day), for: sensor, deviceKey: iphone.key)
                manager.runDeviceChain(at: 0, of: [iphone], for: sensor, now: now, using: mapper)
                expect(mapper.calls.count).toEventually(equal(2 * perProbe), timeout: .seconds(5))
            }

            it("releases the guard on the forward-only bail, so the sensor recovers with consent") {
                let blocking = BlockingDeviceMapper()
                manager.runDeviceChain(at: 0, of: [iphone], for: sensor, now: now, using: blocking)
                expect(blocking.callCount).toEventually(equal(1), timeout: .seconds(5))

                // Consent disappears while the fetch is parked: the completion lands on the
                // forward-only bail, the one chain-termination path outside `runDeviceChain`.
                clearance.enrollmentDate = nil
                expect(blocking.releaseNext()).to(beTrue())
                expect(blocking.callCount).toAlways(equal(1), until: .milliseconds(300))

                // Consent comes back. Without the bail releasing the guard the sensor would be
                // dead until the next app launch.
                clearance.enrollmentDate = now.addingTimeInterval(-10 * day)
                manager.runDeviceChain(at: 0, of: [iphone], for: sensor, now: now, using: blocking)
                expect(blocking.callCount).toEventually(equal(2), timeout: .seconds(5))
            }
        }

        describe("failure isolation between devices") {

            it("keeps walking the remaining devices when the first device's fetches keep failing") {
                mapper.failingDeviceKeys = ["watch"]
                // Watch first, so a chain that "stops for this cycle" would swallow the iPhone's
                // windows entirely if the failure branch did not hand over.
                manager.runDeviceChain(at: 0, of: [watch, iphone], for: sensor, now: now, using: mapper)

                expect(storage.lastCursor(for: sensor, deviceKey: "iphone"))
                    .toEventually(equal(now.addingTimeInterval(-day)), timeout: .seconds(5))
                // The failing device forfeits nothing: its cursor is left where it was.
                expect(storage.lastCursor(for: sensor, deviceKey: "watch")).to(beNil())
            }

            it("aborts every remaining device chain when consent disappears mid-flight") {
                clearance.enrollmentDate = nil
                let window = DateInterval(start: now.addingTimeInterval(-2 * day), end: now.addingTimeInterval(-day))
                let context = SensorSampleUploadManager.DeviceChainContext(sensor: sensor,
                                                                           device: watch,
                                                                           devices: [watch, iphone],
                                                                           deviceIndex: 0,
                                                                           now: now,
                                                                           mapper: mapper,
                                                                           plannedBound: now.addingTimeInterval(-10 * day))
                manager.handleWindowResult(.success([]), window: window, at: 0, of: [window], context: context)

                expect(mapper.calls).toAlways(beEmpty(), until: .milliseconds(300))
                expect(storage.lastCursor(for: sensor, deviceKey: "iphone")).to(beNil())
                expect(storage.lastCursor(for: sensor, deviceKey: "watch")).to(beNil())
            }
        }

        describe("no devices enumerated yet (identical to pre-FUAM-3945 behaviour)") {

            let provider = DefaultSensorDeviceProvider()

            it("answers with the current device only, and never blocks on the SensorKit delegate") {
                let devices = provider.devices(for: sensor)
                expect(devices.count).to(equal(1))
                expect(devices.first?.key).to(equal(SensorDevice.iphoneKey))
                expect(devices.first?.device).to(beNil())
            }

            it("never enumerates the denylisted high-rate sensors") {
                // Both are disabled today; the denylist keeps "re-enable it" and "fetch it from
                // the Watch" two separate decisions.
                expect(provider.devices(for: .accelerometer).map { $0.key }).to(equal([SensorDevice.iphoneKey]))
                expect(provider.devices(for: .rotationRate).map { $0.key }).to(equal([SensorDevice.iphoneKey]))
            }

            it("puts the current device first and never drops it, whatever enumeration returns") {
                let ordered = DefaultSensorDeviceProvider.ordered([watch])
                expect(ordered.map { $0.key }).to(equal([SensorDevice.iphoneKey, SensorDevice.watchKey]))
            }

            it("probes the backfill and parks the iPhone cursor at the head when only the current device exists") {
                manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

                // AC1: an all-empty store costs `probeEmptyWindowStop` fetches, and the cursor
                // still ends at the newest complete day — same terminal state as the old walk.
                expect(mapper.calls.count)
                    .toEventually(equal(SensorSampleUploadManager.probeEmptyWindowStop), timeout: .seconds(5))
                expect(storage.lastCursor(for: sensor, deviceKey: SensorDevice.iphoneKey))
                    .to(equal(now.addingTimeInterval(-day)))
            }
        }
    }
}

/// Records which device each fetch was made for and can be told to fail one device's fetches.
/// Completes SYNCHRONOUSLY, so it can never observe two fetches overlapping — use
/// `BlockingDeviceMapper` for anything about concurrency (review C1).
private final class RecordingDeviceMapper: SensorSampleMapper {

    struct Call {
        let deviceKey: String
        let window: DateInterval
    }

    private let lock = NSLock()
    private var recorded: [Call] = []

    /// Set before driving the chain.
    var records: [[String: Any]] = []
    var failingDeviceKeys: Set<String> = []

    var calls: [Call] { return self.lock.locked { self.recorded } }

    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let shouldFail: Bool = self.lock.locked {
            self.recorded.append(Call(deviceKey: device.key, window: DateInterval(start: from, end: to)))
            return self.failingDeviceKeys.contains(device.key)
        }
        let payload = self.records
        if shouldFail {
            completion(.failure(NSError(domain: "spec.mapper", code: 1)))
        } else {
            completion(.success(payload))
        }
    }
}

/// A mapper that never completes on its own: every fetch parks its completion until the spec
/// releases it. That is what makes a chain observably "mid-fetch" and lets a second sync cycle
/// arrive while the first is still in flight (review C1) — the case the real single-flight
/// mappers answer with `.busy`, and used to answer with a `precondition` crash.
private final class BlockingDeviceMapper: SensorSampleMapper {

    private let lock = NSLock()
    private var recorded: [String] = []
    private var held: [(Result<[[String: Any]], Error>) -> Void] = []

    var callCount: Int { return self.lock.locked { self.recorded.count } }

    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        self.lock.locked {
            self.recorded.append(device.key)
            self.held.append(completion)
        }
    }

    /// Complete the oldest parked fetch with an empty success. `false` when none is parked.
    @discardableResult
    func releaseNext() -> Bool {
        let next: ((Result<[[String: Any]], Error>) -> Void)? = self.lock.locked {
            return self.held.isEmpty ? nil : self.held.removeFirst()
        }
        next?(.success([]))
        return next != nil
    }
}

// MARK: - FUAM-3964 (F1): a HealthKit cursor burnt into the future

/// The HealthKit mirror of the SensorKit reset. An offline forward clock excursion runs the walk
/// uncapped and persists `uploadStartDate` in the future; once the clock is corrected the walk
/// parks (`startDate >= endDate`) and, when real time finally passes the cursor, resumes AT it —
/// so the interval in between was never fetched and never reported. It is now detected, reported
/// as `future_cursor` carrying the corrupt cursor, and reset to the consent bound.
///
/// Also pins F9: the reach event used to be gated on `uploadStartDate == nil`, i.e. it never fired
/// for an install that already had a cursor — the entire upgrade cohort.
class HealthFutureCursorSpec: QuickSpec {

    override class func spec() {

        let day: TimeInterval = 24 * 3600
        let dataType = HealthDataType.stepCount

        var storage: FakeHealthStorage!
        var analytics: CapturingAnalyticsService!
        var clearance: FakeHealthClearance!
        var network: FakeHealthNetwork!
        var attempted: [DateInterval]!

        beforeEach {
            storage = FakeHealthStorage()
            analytics = CapturingAnalyticsService()
            clearance = FakeHealthClearance()
            network = FakeHealthNetwork()
            clearance.enrollmentDate = Date().addingTimeInterval(-10 * day)
            attempted = []
        }

        /// Runs the real `startUpload` walk with every chunk succeeding.
        func walk() {
            let manager = HealthSampleUploadManager(withDataTypes: [dataType],
                                                    storage: storage,
                                                    reachability: FakeHealthReachability(),
                                                    analytics: analytics)
            manager.clearanceDelegate = clearance
            manager.setNetworkDelegate(network)
            manager.uploadChunk = { _, chunk, _ in
                attempted.append(chunk)
                return Single.just(())
            }
            guard let uploader = manager.uploaders.first else {
                fail("no uploader for \(dataType.keyName)")
                return
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

        it("resets a cursor burnt into the future and re-walks from the consent bound") {
            let burned = Date().addingTimeInterval(3 * day)
            storage.setUploadStartDate(burned, forDataType: dataType)

            walk()

            // Reported once, with the corrupt cursor as the reach so the gap size is readable.
            expect(reachEvents(boundedBy: .futureCursor)).to(equal([ISO8601DateFormatter().string(from: burned)]))
            // The walk actually re-fetched: it opened at the consent bound, not at the cursor.
            expect(attempted.first?.start).to(beCloseTo(Date().addingTimeInterval(-10 * day), within: 5))
            expect(storage.uploadStartDate(forDataType: dataType)).to(equal(attempted.last?.end))
        }

        it("leaves a cursor inside the tolerance alone") {
            // Half a day ahead is not provably corrupt (clock jitter, a chunk end rounded up),
            // so the old contract holds: never rewind, park until real time catches up.
            let nearFuture = Date().addingTimeInterval(day / 2)
            storage.setUploadStartDate(nearFuture, forDataType: dataType)

            walk()

            expect(reachEvents(boundedBy: .futureCursor)).to(beEmpty())
            expect(attempted).to(beEmpty())
            expect(storage.uploadStartDate(forDataType: dataType)).to(equal(nearFuture))
        }

        it("reports the reach for an install that already has a cursor below the bound (F9)") {
            // The upgrade cohort: a cursor exists, but it predates the consent bound and is
            // clamped to it — a real backfill decision, which used to be reported by nobody.
            storage.setUploadStartDate(Date().addingTimeInterval(-30 * day), forDataType: dataType)

            walk()

            expect(reachEvents(boundedBy: .joinDate)).to(haveCount(1))
        }

        it("stays silent on a routine cursor resume") {
            storage.setUploadStartDate(Date().addingTimeInterval(-2 * day), forDataType: dataType)

            walk()

            expect(reachEvents(boundedBy: .joinDate)).to(beEmpty())
            expect(reachEvents(boundedBy: .futureCursor)).to(beEmpty())
        }
    }
}

// MARK: - FUAM-3945 (F6): the HealthKit per-sample consent gate

/// `HealthSampleUploader.consentFiltered` is the ONLY per-sample consent gate in the HealthKit
/// path, and until this spec nothing executed it: every chunk-walk spec substitutes the
/// `uploadChunk` seam, which bypasses the uploader wholesale. `HKQuantitySample` is constructible
/// without any store access, so the gate can be driven directly.
class HealthConsentFilterSpec: QuickSpec {

    override class func spec() {

        let hour: TimeInterval = 3600
        let bound = Date().addingTimeInterval(-24 * hour)

        func sample(at date: Date) -> HKQuantitySample? {
            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
            return HKQuantitySample(type: type,
                                    quantity: HKQuantity(unit: .count(), doubleValue: 1),
                                    start: date,
                                    end: date)
        }

        describe("consentFiltered") {

            it("keeps a sample stamped exactly at the bound") {
                // `>=`, not `>`: the bound is the START of the join day.
                guard let atBound = sample(at: bound) else { return fail("no step count type") }
                expect(HealthSampleUploader.consentFiltered([atBound], minimum: bound)).to(haveCount(1))
            }

            it("drops everything measured before the bound and keeps everything after") {
                guard let before = sample(at: bound.addingTimeInterval(-1)),
                      let after = sample(at: bound.addingTimeInterval(1)) else { return fail("no step count type") }
                let kept = HealthSampleUploader.consentFiltered([before, after], minimum: bound)
                expect(kept.map { $0.startDate }).to(equal([after.startDate]))
            }

            it("returns nothing when every sample predates the bound") {
                guard let older = sample(at: bound.addingTimeInterval(-10 * hour)),
                      let oldest = sample(at: bound.addingTimeInterval(-100 * hour)) else { return fail("no step count type") }
                expect(HealthSampleUploader.consentFiltered([older, oldest], minimum: bound)).to(beEmpty())
            }

            it("handles an empty input") {
                expect(HealthSampleUploader.consentFiltered([], minimum: bound)).to(beEmpty())
            }
        }

        describe("serializedSize (the pre-flight payload gate)") {

            it("measures the JSON the request will actually carry") {
                let payload: HealthNetworkData = ["a": "bc"]
                // {"a":"bc"} — 10 bytes, and under the cap.
                expect(HealthSampleUploader.serializedSize(of: payload)).to(equal(10))
                expect(HealthSampleUploader.serializedSize(of: payload) ?? 0)
                    .to(beLessThan(Constants.HealthKit.MaxUploadPayloadBytes))
            }

            it("sees a payload over the 8 MB cap as over the cap") {
                let big: HealthNetworkData = ["data": String(repeating: "x", count: 9 * 1024 * 1024)]
                guard let size = HealthSampleUploader.serializedSize(of: big) else {
                    return fail("an oversize payload must still be measurable")
                }
                expect(size).to(beGreaterThan(Constants.HealthKit.MaxUploadPayloadBytes))
            }

            it("returns nil rather than a guess for something that cannot be serialized") {
                // nil means "send it anyway": a rejected request is recoverable, a chunk skipped
                // on a guess is not.
                expect(HealthSampleUploader.serializedSize(of: ["date": Date()])).to(beNil())
            }
        }

        describe("the 413 discriminator behind uploadPayloadTooLarge") {

            let request = ApiRequest(serviceRequest: .sendHealthData(healthData: [:], source: "health_kit"))

            it("reads the status code the oversize mapping branches on") {
                let error = ApiError.unexpectedError(pathUrl: "/health", request: request,
                                                     statusCode: 413, responseBody: "")
                expect(error.httpStatusCode).to(equal(413))
            }

            it("has no status code for a connectivity failure, which must not read as oversize") {
                expect(ApiError.connectivity.httpStatusCode).to(beNil())
                expect(ApiError.network(pathUrl: "/health", request: request,
                                        underlyingError: TestError.generic).httpStatusCode).to(beNil())
            }
        }
    }
}

// MARK: - FUAM-3945 (F7): the legacy upload-queue purge

/// A batch persisted by a pre-FUAM-3945 build is a bare array of records with no window start, and
/// the drain-time consent gate cannot decide it (its undecidable records would be dropped anyway).
/// It is purged on the first load after the upgrade — silently, but it must neither crash nor
/// survive at rest on the device.
class SensorLegacyQueuePurgeSpec: QuickSpec {

    override class func spec() {

        let sensor = SRSensor.pedometerData
        let key = "sensorkit.queue." + sensor.rawValue
        var storage: DefaultsSensorStorage!

        beforeEach {
            storage = DefaultsSensorStorage()
            // The pre-FUAM-3945 shape: [[[String: Any]]] — an array of batches of records.
            let legacy: [[[String: Any]]] = [[["t": "2025-01-01T00:00:00Z", "steps": 10]],
                                             [["t": "2025-01-02T00:00:00Z", "steps": 20]]]
            guard let data = try? JSONSerialization.data(withJSONObject: legacy) else {
                return fail("could not build the legacy blob")
            }
            UserDefaults.standard.set(data, forKey: key)
        }

        afterEach {
            UserDefaults.standard.removeObject(forKey: key)
        }

        it("drops legacy entries, rewrites the blob and does not crash") {
            expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
            expect(storage.dequeueNextBatch(for: sensor)).to(beNil())

            // Rewritten in the new shape (an empty array), so nothing is left at rest.
            guard let data = UserDefaults.standard.data(forKey: key),
                  let entries = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
                return fail("the queue blob was not rewritten")
            }
            expect(entries).to(beEmpty())
        }

        it("round-trips a new-format batch enqueued right after the purge") {
            let windowStart = Date(timeIntervalSince1970: 1_700_000_000)
            _ = storage.pendingBatchCount(for: sensor)   // triggers the purge
            storage.enqueueBatch([["t": "2025-06-01T00:00:00Z"]], windowStart: windowStart, for: sensor)

            expect(storage.pendingBatchCount(for: sensor)).to(equal(1))
            let head = storage.dequeueNextBatch(for: sensor)
            expect(head?.records.count).to(equal(1))
            expect(head?.windowStart).to(equal(windowStart))
            expect(storage.pendingBatchCount(for: sensor)).to(equal(0))
        }
    }
}

// MARK: - FUAM-3945 (D1): the FETCH span widens; the grid, the cursor and the consent proxy do not

/// D-C in production: `SRPhoneUsageReport` covers one LOCAL calendar day and SensorKit returns a
/// usage report only when its whole period fits inside the fetch range, so a UTC-day fetch can
/// never contain it on a non-UTC device. The fix widens only what is handed to the MAPPER
/// (reports −24h, continuous −1s); the cursor, `enqueueBatch(windowStart:)` and `windowVouches`
/// keep the narrow window (AC6: fetch widens, vouching does not).
class SensorFetchSpanSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let windowStart = SensorSampleUploadManager.utcDayStart(Date().addingTimeInterval(-30 * day))
        let window = DateInterval(start: windowStart, end: windowStart.addingTimeInterval(day))

        describe("fetchSpan(for:window:)") {

            it("widens a report-class fetch by 26h backwards (24h local day + DST/diverging-device margin, F4)") {
                for sensor in [SRSensor.deviceUsageReport, .phoneUsageReport, .messagesUsageReport, .keyboardMetrics] {
                    let span = SensorSampleUploadManager.fetchSpan(for: sensor, window: window)
                    expect(span.start).to(equal(window.start.addingTimeInterval(-26 * hour)))
                }
            }

            it("nudges a continuous fetch 1s backwards (the boundary-instant epsilon)") {
                for sensor in [SRSensor.visits, .pedometerData, .ambientLightSensor, .ambientPressure] {
                    let span = SensorSampleUploadManager.fetchSpan(for: sensor, window: window)
                    expect(span.start).to(equal(window.start.addingTimeInterval(-1)))
                }
            }

            it("never touches the fetch END for either class") {
                expect(SensorSampleUploadManager.fetchSpan(for: .deviceUsageReport, window: window).end)
                    .to(equal(window.end))
                expect(SensorSampleUploadManager.fetchSpan(for: .visits, window: window).end)
                    .to(equal(window.end))
            }

            it("contains any local calendar day, at any UTC offset, in at least one planned window's span") {
                // F4 regression guard for D-C: for every offset in [-14h, +14h] there must be a
                // UTC-day window whose WIDENED span contains the whole local day.
                for offsetHours in -14...14 {
                    let localDayStart = window.start.addingTimeInterval(TimeInterval(-offsetHours) * hour)
                    let localDay = DateInterval(start: localDayStart, end: localDayStart.addingTimeInterval(day))
                    // Candidate planned windows: the UTC days overlapping the local day.
                    let candidates = [-day, 0, day].map { offset -> DateInterval in
                        let start = SensorSampleUploadManager.utcDayStart(localDayStart.addingTimeInterval(offset + day))
                        return DateInterval(start: start, end: start.addingTimeInterval(day))
                    }
                    let contained = candidates.contains { candidate in
                        let span = SensorSampleUploadManager.fetchSpan(for: .phoneUsageReport, window: candidate)
                        return span.start <= localDay.start && localDay.end <= span.end
                    }
                    expect(contained).to(beTrue(), description: "no widened window contains the local day at UTC\(offsetHours)")
                }
            }
        }

        describe("processWindow (the one seam that widens)") {

            let sensor = SRSensor.deviceUsageReport
            let planningNow = SensorSampleUploadManager.utcDayStart(Date())

            var storage: FakeSensorStorage!
            var clearance: FakeSensorClearance!
            var mapper: RecordingDeviceMapper!
            var manager: SensorSampleUploadManager!

            beforeEach {
                storage = FakeSensorStorage()
                clearance = FakeSensorClearance()
                clearance.enrollmentDate = planningNow.addingTimeInterval(-30 * day)
                mapper = RecordingDeviceMapper()
                manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: CapturingAnalyticsService(),
                                                    mappers: [sensor: mapper])
                manager.clearanceDelegate = clearance
                // Routine cursor resume, so this exercises the plain forward walk.
                storage.setLastCursor(planningNow.addingTimeInterval(-3 * day), for: sensor)
            }

            it("hands the mapper the widened span and everything else the narrow window") {
                let recordStart = planningNow.addingTimeInterval(-2 * day + hour)
                mapper.records = [["start": ISO8601DateFormatter().string(from: recordStart),
                                   "duration_s": 3600,
                                   "recorded_at": ISO8601DateFormatter().string(from: recordStart.addingTimeInterval(hour))]]

                manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: planningNow, using: mapper)

                expect(mapper.calls.count).toEventually(beGreaterThan(0), timeout: .seconds(5))
                expect(storage.enqueued.count).toEventually(beGreaterThan(0), timeout: .seconds(5))
                // Every fetch spans [W − 24h, W + 24h) for a UTC-day window [W, W + 24h).
                for call in mapper.calls {
                    let narrowStart = call.window.start.addingTimeInterval(26 * hour)
                    expect(call.window.duration).to(equal(day + 26 * hour))
                    expect(narrowStart).to(equal(SensorSampleUploadManager.utcDayStart(narrowStart)))
                }
                // The enqueue keeps the NARROW window start (the consent gate re-reads it at
                // drain time; a widened value would let a pre-join report be vouched for).
                for batch in storage.enqueued {
                    expect(batch.windowStart).to(equal(SensorSampleUploadManager.utcDayStart(batch.windowStart)))
                    let widened = mapper.calls.contains { $0.window.start.addingTimeInterval(26 * hour) == batch.windowStart }
                    expect(widened).to(beTrue())
                }
                // The cursor is owned by the narrow grid: it ends at the last complete UTC day.
                expect(storage.lastCursor(for: sensor)).toEventually(equal(planningNow.addingTimeInterval(-day)),
                                                                     timeout: .seconds(5))
            }
        }
    }
}

// MARK: - FUAM-3945 AC2 (revised): the participant-timezone partition

/// Window/batch boundaries are a pure function of (absolute time, the BACKEND-authoritative
/// `user.time_zone`) — the same authority the adherence chart buckets rows with. Never the
/// handset's timezone, never a fixed 86400-second stride (DST days are 23 or 25 hours long).
class SensorPartitionSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let rome = TimeZone(identifier: "Europe/Rome")!
        var romeCalendar = Calendar(identifier: .gregorian)
        romeCalendar.timeZone = rome

        func plan(now: Date, joinDay: Date?, cursor: Date?, timeZone: TimeZone) -> SensorSampleUploadManager.WindowPlan {
            return SensorSampleUploadManager.buildWindowPlan(now: now,
                                                             boundNow: now,
                                                             joinDay: joinDay,
                                                             cursor: cursor,
                                                             embargo: day,
                                                             timeZone: timeZone)
        }

        it("cuts windows on participant-timezone day boundaries, not UTC midnights") {
            // 2026-08-10 12:00:00 UTC; Rome is UTC+2 in August.
            let now = Date(timeIntervalSince1970: 1786104000)
            let joinDay = romeCalendar.startOfDay(for: now.addingTimeInterval(-5 * day))
            let result = plan(now: now, joinDay: joinDay, cursor: nil, timeZone: rome)
            expect(result.windows).toNot(beEmpty())
            for window in result.windows {
                expect(window.start).to(equal(romeCalendar.startOfDay(for: window.start)))
                expect(window.start).toNot(equal(SensorSampleUploadManager.utcDayStart(window.start)))
            }
            for (previous, next) in zip(result.windows, result.windows.dropFirst()) {
                expect(previous.end).to(equal(next.start))
            }
        }

        it("plans a 23-hour window across the DST spring-forward day, with no gap or overlap") {
            // EU spring-forward 2026: Sunday 2026-03-29 (02:00 -> 03:00 in Rome).
            // 2026-04-02 12:00:00 UTC.
            let now = Date(timeIntervalSince1970: 1775131200)
            let joinDay = romeCalendar.startOfDay(for: now.addingTimeInterval(-7 * day))
            let result = plan(now: now, joinDay: joinDay, cursor: nil, timeZone: rome)
            let durations = result.windows.map { $0.duration }
            expect(durations).to(contain(23 * hour))
            expect(durations.filter { $0 != 23 * hour && $0 != 24 * hour }).to(beEmpty())
            for (previous, next) in zip(result.windows, result.windows.dropFirst()) {
                expect(previous.end).to(equal(next.start))
            }
        }

        it("plans a 25-hour window across the DST fall-back day, with no gap or overlap") {
            // EU fall-back 2026: Sunday 2026-10-25 (03:00 -> 02:00 in Rome).
            // 2026-10-29 12:00:00 UTC.
            let now = Date(timeIntervalSince1970: 1793275200)
            let joinDay = romeCalendar.startOfDay(for: now.addingTimeInterval(-7 * day))
            let result = plan(now: now, joinDay: joinDay, cursor: nil, timeZone: rome)
            let durations = result.windows.map { $0.duration }
            expect(durations).to(contain(25 * hour))
            expect(durations.filter { $0 != 25 * hour && $0 != 24 * hour }).to(beEmpty())
            for (previous, next) in zip(result.windows, result.windows.dropFirst()) {
                expect(previous.end).to(equal(next.start))
            }
        }

        it("is invariant to the HANDSET timezone while user.time_zone is held fixed (AC3)") {
            let now = Date(timeIntervalSince1970: 1786104000)
            let joinDay = romeCalendar.startOfDay(for: now.addingTimeInterval(-4 * day))
            let original = NSTimeZone.default
            var plans: [[DateInterval]] = []
            for identifier in ["UTC", "Asia/Tokyo", "Pacific/Kiritimati", "America/Los_Angeles"] {
                NSTimeZone.default = TimeZone(identifier: identifier)!
                plans.append(plan(now: now, joinDay: joinDay, cursor: nil, timeZone: rome).windows)
            }
            NSTimeZone.default = original
            for other in plans.dropFirst() {
                expect(other).to(equal(plans[0]))
            }
        }

        it("reproduces byte-identical batches and anchors after a wipe + device-timezone change (AC2)") {
            // The reinstall simulation: same underlying records, fresh client state, different
            // handset timezone — the partition, the batches and the client-side anchor
            // (min recorded_at, what the server derives retrieved_at from) must not move.
            let sensor = SRSensor.deviceUsageReport
            let now = SensorSampleUploadManager.utcDayStart(Date())
            let joinDay = romeCalendar.startOfDay(for: now.addingTimeInterval(-6 * day))
            let recordTime = now.addingTimeInterval(-2 * day + 3 * hour)
            let records: [[String: Any]] = [
                ["start": ISO8601DateFormatter().string(from: recordTime),
                 "duration_s": 3600,
                 "recorded_at": ISO8601DateFormatter().string(from: recordTime.addingTimeInterval(hour))],
                ["start": ISO8601DateFormatter().string(from: recordTime.addingTimeInterval(2 * hour)),
                 "duration_s": 3600,
                 "recorded_at": ISO8601DateFormatter().string(from: recordTime.addingTimeInterval(3 * hour))]
            ]

            func runOnce(deviceTimeZone: String) -> [(records: [[String: Any]], windowStart: Date)] {
                let original = NSTimeZone.default
                NSTimeZone.default = TimeZone(identifier: deviceTimeZone)!
                defer { NSTimeZone.default = original }
                let storage = FakeSensorStorage()
                let clearance = FakeSensorClearance()
                clearance.enrollmentDate = joinDay
                clearance.participantTimeZone = rome
                let mapper = RecordingDeviceMapper()
                mapper.records = records
                let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                        storage: storage,
                                                        reachability: FakeSensorReachability(),
                                                        analytics: CapturingAnalyticsService(),
                                                        mappers: [sensor: mapper])
                manager.clearanceDelegate = clearance
                manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)
                expect(storage.enqueued.count).toEventually(beGreaterThan(0), timeout: .seconds(5))
                return storage.enqueued
            }

            let first = runOnce(deviceTimeZone: "Pacific/Auckland")
            let second = runOnce(deviceTimeZone: "America/Los_Angeles")

            expect(second.count).to(equal(first.count))
            for (batchA, batchB) in zip(first, second) {
                expect(batchB.windowStart).to(equal(batchA.windowStart))
                let bytesA = SensorUploadLedger.canonical(["records": batchA.records])
                let bytesB = SensorUploadLedger.canonical(["records": batchB.records])
                expect(bytesB).to(equal(bytesA))
                // The client-side anchor: min recorded_at over the batch.
                let anchorA = batchA.records.compactMap { $0["recorded_at"] as? String }.min()
                let anchorB = batchB.records.compactMap { $0["recorded_at"] as? String }.min()
                expect(anchorB).to(equal(anchorA))
            }
        }

        it("plans on the device clock capped by server time even 30 days ahead or behind (AC3)") {
            let sensor = SRSensor.pedometerData
            defer { UserDefaults.standard.removeObject(forKey: ServerClock.storageKey) }

            // Device 30 days AHEAD: no window may end past serverNow - embargo.
            let deviceAhead = Date()
            UserDefaults.standard.set(-30 * day, forKey: ServerClock.storageKey)
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = deviceAhead.addingTimeInterval(-60 * day)
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: CapturingAnalyticsService(),
                                                    mappers: [sensor: RecordingDeviceMapper()])
            manager.clearanceDelegate = clearance
            let ahead = manager.buildWindowPlan(for: sensor, now: deviceAhead, device: .current)
            expect(ahead.windows.last?.end)
                .to(beLessThanOrEqualTo(deviceAhead.addingTimeInterval(-30 * day - day)))

            // Device 30 days BEHIND: the 365-day floor is measured from the LATER clock.
            UserDefaults.standard.set(30 * day, forKey: ServerClock.storageKey)
            clearance.enrollmentDate = deviceAhead.addingTimeInterval(-500 * day)
            let behind = manager.buildWindowPlan(for: sensor, now: deviceAhead, device: .current)
            expect(behind.consentBound)
                .to(beGreaterThan(deviceAhead.addingTimeInterval(-365 * day)))
        }

        it("falls back to UTC — never the handset timezone — and reports it, when user.time_zone is missing") {
            let sensor = SRSensor.pedometerData
            let now = SensorSampleUploadManager.utcDayStart(Date())
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = now.addingTimeInterval(-4 * day)
            clearance.participantTimeZone = nil
            let analytics = CapturingAnalyticsService()
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: analytics,
                                                    mappers: [sensor: RecordingDeviceMapper()])
            manager.clearanceDelegate = clearance

            let original = NSTimeZone.default
            NSTimeZone.default = TimeZone(identifier: "Pacific/Kiritimati")!
            let result = manager.buildWindowPlan(for: sensor, now: now, device: .current)
            NSTimeZone.default = original

            for window in result.windows {
                expect(window.start).to(equal(SensorSampleUploadManager.utcDayStart(window.start)))
            }
            let fallbacks = analytics.trackedEvents.filter {
                if case .sensorTimezoneFallback = $0 { return true }
                return false
            }
            expect(fallbacks.count).to(equal(1))
        }
    }
}

// MARK: - FUAM-3945 (D3): the rescan tail

class SensorRescanTailSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let sensor = SRSensor.deviceUsageReport
        let now = SensorSampleUploadManager.utcDayStart(Date())
        let joinDay = now.addingTimeInterval(-30 * day)
        // With a 24h embargo and `now` on a UTC midnight, safeTo = now - 1d (aligned).
        let tail = now.addingTimeInterval(-4 * day)   // dayStart(safeTo) - 3 days

        func plan(cursor: Date?, rescanFrom: Date?) -> SensorSampleUploadManager.WindowPlan {
            return SensorSampleUploadManager.buildWindowPlan(now: now,
                                                             boundNow: now,
                                                             joinDay: joinDay,
                                                             cursor: cursor,
                                                             embargo: day,
                                                             rescanFrom: rescanFrom)
        }

        it("re-plans the tail days behind the cursor when the rescan is due") {
            let cursor = now.addingTimeInterval(-day)
            let result = plan(cursor: cursor, rescanFrom: tail)
            expect(result.windows.first?.start).to(equal(tail))
            expect(result.rescanFrom).to(equal(tail))
            // Routine pass: the origin must stay `.cursor`, so no reach telemetry fires daily.
            expect(result.lowerBoundOrigin).to(equal(BackfillLowerBound.Origin.cursor))
        }

        it("keeps the plain cursor resume when the rescan is not due") {
            let cursor = now.addingTimeInterval(-2 * day)
            let result = plan(cursor: cursor, rescanFrom: nil)
            expect(result.windows.first?.start).to(equal(cursor))
            expect(result.rescanFrom).to(beNil())
        }

        it("never rewinds below the consent bound") {
            let bound = now.addingTimeInterval(-2 * day)
            let result = SensorSampleUploadManager.buildWindowPlan(now: now,
                                                                   boundNow: now,
                                                                   joinDay: bound,
                                                                   cursor: now.addingTimeInterval(-day),
                                                                   embargo: day,
                                                                   rescanFrom: tail)
            expect(result.windows.first?.start).to(equal(bound))
        }

        it("does not touch a plan already starting at or before the tail") {
            let cursor = now.addingTimeInterval(-10 * day)
            let result = plan(cursor: cursor, rescanFrom: tail)
            expect(result.windows.first?.start).to(equal(cursor))
            expect(result.rescanFrom).to(beNil())
        }

        it("re-plans the tail as whole grid days, so re-fetches reproduce the original windows") {
            let result = plan(cursor: now.addingTimeInterval(-day), rescanFrom: tail)
            for window in result.windows {
                expect(window.start).to(equal(SensorSampleUploadManager.utcDayStart(window.start)))
                expect(window.duration).to(equal(day))
            }
        }

        describe("the manager-level gate and cursor safety") {

            var storage: FakeSensorStorage!
            var clearance: FakeSensorClearance!
            var analytics: CapturingAnalyticsService!
            var mapper: RecordingDeviceMapper!
            var manager: SensorSampleUploadManager!

            beforeEach {
                storage = FakeSensorStorage()
                clearance = FakeSensorClearance()
                clearance.enrollmentDate = joinDay
                analytics = CapturingAnalyticsService()
                mapper = RecordingDeviceMapper()
                manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: analytics,
                                                    mappers: [sensor: mapper])
                manager.clearanceDelegate = clearance
            }

            it("arms the tail at most once per day (a 15-second sync cadence cannot multiply it)") {
                storage.setLastCursor(now.addingTimeInterval(-day), for: sensor)
                let first = manager.buildWindowPlan(for: sensor, now: now, device: .current)
                let second = manager.buildWindowPlan(for: sensor, now: now, device: .current)
                expect(first.rescanFrom).toNot(beNil())
                expect(second.rescanFrom).to(beNil())
                expect(second.windows).to(beEmpty())   // plain resume from the head cursor
            }

            it("re-reads windows behind the cursor without ever rewinding it (D-D fix, AC4)") {
                let head = now.addingTimeInterval(-day)
                storage.setLastCursor(head, for: sensor)
                mapper.records = [["t": ISO8601DateFormatter().string(from: now.addingTimeInterval(-3 * day + hour))]]

                manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

                // The three tail days were re-fetched...
                expect(mapper.calls.count).toEventually(equal(3), timeout: .seconds(5))
                // ...their novel records enqueued...
                expect(storage.enqueued.count).toEventually(beGreaterThan(0), timeout: .seconds(5))
                // ...and the cursor never moved backwards.
                expect(storage.lastCursor(for: sensor)).toAlways(equal(head), until: .milliseconds(300))
            }

            it("reports novel records found on a rescan pass (the D-D completion curve)") {
                storage.setLastCursor(now.addingTimeInterval(-day), for: sensor)
                mapper.records = [["t": ISO8601DateFormatter().string(from: now.addingTimeInterval(-2 * day + hour))]]

                manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

                func novelCounts() -> [Int] {
                    return analytics.trackedEvents.compactMap { event in
                        if case let .sensorRescanNovel(_, _, _, novelCount) = event { return novelCount }
                        return nil
                    }
                }
                expect(novelCounts()).toEventuallyNot(beEmpty(), timeout: .seconds(5))
                expect(novelCounts().reduce(0, +)).to(beGreaterThan(0))
            }
        }
    }
}

// MARK: - FUAM-3945 (D4): the upload ledger and its canonical serializer

class SensorUploadLedgerSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let windowDay = SensorSampleUploadManager.utcDayStart(Date().addingTimeInterval(-2 * day))

        describe("the canonical serializer (the load-bearing property: byte stability)") {

            it("hashes the same logical record identically however it was built") {
                // Same record, two constructions: different key insertion order, Int vs Double
                // NSNumber boxing, nested containers built separately.
                var recordA: [String: Any] = [:]
                recordA["duration_s"] = 900
                recordA["recorded_at"] = "2026-08-26T00:14:59Z"
                recordA["nested"] = ["b": 2, "a": [1, 2, 3]] as [String: Any]
                recordA["flag"] = true

                var recordB: [String: Any] = [:]
                recordB["flag"] = true
                var nested: [String: Any] = [:]
                nested["a"] = [NSNumber(value: 1.0), NSNumber(value: 2.0), NSNumber(value: 3.0)]
                nested["b"] = NSNumber(value: 2.0)
                recordB["nested"] = nested
                recordB["recorded_at"] = "2026-08-26T00:14:59Z"
                recordB["duration_s"] = NSNumber(value: 900.0)

                expect(SensorUploadLedger.fingerprint(of: recordB))
                    .to(equal(SensorUploadLedger.fingerprint(of: recordA)))
            }

            it("does not confuse a boolean with the integer 1") {
                expect(SensorUploadLedger.canonical(["v": true])).toNot(equal(SensorUploadLedger.canonical(["v": 1])))
            }

            it("renders fractional doubles deterministically and integral doubles as integers") {
                expect(SensorUploadLedger.canonical(["v": 0.1])).to(equal(SensorUploadLedger.canonical(["v": 0.1])))
                expect(SensorUploadLedger.canonical(["v": NSNumber(value: 42.0)]))
                    .to(equal(SensorUploadLedger.canonical(["v": 42])))
                expect(SensorUploadLedger.canonical(["v": 0.1])).toNot(equal(SensorUploadLedger.canonical(["v": 0.2])))
            }

            it("sorts keys, so dictionary iteration order can never leak into the fingerprint") {
                expect(SensorUploadLedger.canonical(["b": 1, "a": 2]))
                    .to(equal("{\"a\":2,\"b\":1}"))
            }

            it("escapes strings byte-wise, locale-free") {
                expect(SensorUploadLedger.canonical(["s": "a\"b\\c\n"]))
                    .to(equal("{\"s\":\"a\\\"b\\\\c\\u000a\"}"))
            }
        }

        describe("filter") {

            let sensor = SRSensor.deviceUsageReport
            let record: [String: Any] = ["start": "2026-08-26T00:00:00Z",
                                         "duration_s": 3600,
                                         "recorded_at": "2026-08-26T01:00:00Z"]

            it("drops a record whose fingerprint is already in the ledger") {
                let first = SensorUploadLedger.filter(records: [record], sensor: sensor, windowDay: windowDay, ledger: [:])
                expect(first.novel.count).to(equal(1))
                let second = SensorUploadLedger.filter(records: [record],
                                                       sensor: sensor,
                                                       windowDay: windowDay,
                                                       ledger: first.newEntries)
                expect(second.novel).to(beEmpty())
                expect(second.duplicateCount).to(equal(1))
            }

            it("drops a duplicate within one batch") {
                let result = SensorUploadLedger.filter(records: [record, record],
                                                       sensor: sensor,
                                                       windowDay: windowDay,
                                                       ledger: [:])
                expect(result.novel.count).to(equal(1))
                expect(result.duplicateCount).to(equal(1))
            }

            it("keeps a drifted record (different bytes) and counts it as a near-duplicate") {
                let first = SensorUploadLedger.filter(records: [record], sensor: sensor, windowDay: windowDay, ledger: [:])
                var drifted = record
                drifted["recorded_at"] = "2026-08-26T01:01:00Z"   // S7: boundary moved a minute
                let second = SensorUploadLedger.filter(records: [drifted],
                                                       sensor: sensor,
                                                       windowDay: windowDay,
                                                       ledger: first.newEntries)
                expect(second.novel.count).to(equal(1))            // uploaded — never suppressed
                expect(second.nearDuplicateCount).to(equal(1))     // but measured
            }

            it("treats a non-overlapping late record as genuinely novel, not a near-duplicate") {
                let first = SensorUploadLedger.filter(records: [record], sensor: sensor, windowDay: windowDay, ledger: [:])
                let late: [String: Any] = ["start": "2026-08-26T16:00:00Z",
                                           "duration_s": 3600,
                                           "recorded_at": "2026-08-26T17:00:00Z"]
                let second = SensorUploadLedger.filter(records: [late],
                                                       sensor: sensor,
                                                       windowDay: windowDay,
                                                       ledger: first.newEntries)
                expect(second.novel.count).to(equal(1))
                expect(second.nearDuplicateCount).to(equal(0))
            }

            it("prunes by window day and keeps everything at or after the cutoff") {
                let old = SensorLedgerEntry(day: windowDay.addingTimeInterval(-6 * day))
                let recent = SensorLedgerEntry(day: windowDay)
                let pruned = SensorUploadLedger.pruned(["old": old, "recent": recent],
                                                       keepingDaysOnOrAfter: windowDay.addingTimeInterval(-day))
                expect(pruned.keys.sorted()).to(equal(["recent"]))
            }
        }

        describe("persistence") {

            let sensor = SRSensor.messagesUsageReport
            let ledgerKey = "sensorkit.ledger." + sensor.rawValue

            afterEach { UserDefaults.standard.removeObject(forKey: ledgerKey) }

            it("round-trips per device and purges per sensor (the purge path clears it with the queue)") {
                let storage = DefaultsSensorStorage()
                let entry = SensorLedgerEntry(day: windowDay,
                                              periodStart: windowDay,
                                              periodEnd: windowDay.addingTimeInterval(hour))
                storage.setLedger(["fp1": entry], for: sensor, deviceKey: "iphone")
                storage.setLedger(["fp2": SensorLedgerEntry(day: windowDay)], for: sensor, deviceKey: "watch")

                expect(storage.ledger(for: sensor, deviceKey: "iphone")["fp1"]).to(equal(entry))
                expect(storage.ledger(for: sensor, deviceKey: "watch").count).to(equal(1))

                storage.purgeLedger(for: sensor)
                expect(storage.ledger(for: sensor, deviceKey: "iphone")).to(beEmpty())
                expect(storage.ledger(for: sensor, deviceKey: "watch")).to(beEmpty())
            }
        }
    }
}

// MARK: - FUAM-3945 (AC1): the adaptive backfill probe

/// A backfill reaches as far back as the OS actually holds data — bounded only by the join day,
/// the 365-day cap and the cursor, never by a hardcoded retention assumption. The walk probes
/// newest-first and stops after `probeEmptyWindowStop` consecutive confirmed-empty windows.
class SensorBackfillProbeSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let sensor = SRSensor.pedometerData
        let now = SensorSampleUploadManager.utcDayStart(Date())
        let stop = SensorSampleUploadManager.probeEmptyWindowStop

        var storage: FakeSensorStorage!
        var clearance: FakeSensorClearance!
        var analytics: CapturingAnalyticsService!
        var manager: SensorSampleUploadManager!
        var mapper: ClosureDeviceMapper!

        func makeManager(retainedDays: Double) {
            storage = FakeSensorStorage()
            clearance = FakeSensorClearance()
            clearance.enrollmentDate = now.addingTimeInterval(-60 * day)
            analytics = CapturingAnalyticsService()
            let productiveFrom = now.addingTimeInterval(-retainedDays * day)
            mapper = ClosureDeviceMapper { _, to in
                // The OS "holds" data for the last `retainedDays` days: a window whose end is
                // inside that horizon returns one record, an older one returns nothing.
                guard to > productiveFrom else { return [] }
                return [["t": ISO8601DateFormatter().string(from: to.addingTimeInterval(-hour))]]
            }
            manager = SensorSampleUploadManager(withSensors: [sensor],
                                                storage: storage,
                                                reachability: FakeSensorReachability(),
                                                analytics: analytics,
                                                mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance
        }

        it("reaches 25 days back when the OS holds 25 days — no hardcoded horizon") {
            makeManager(retainedDays: 25)
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            // 24 productive windows (ends -24d .. -1d) + `stop` empty probes, newest-first.
            expect(mapper.callCount).toEventually(equal(24 + stop), timeout: .seconds(5))
            expect(storage.deepestProductiveWindowStart(for: sensor)).to(equal(now.addingTimeInterval(-25 * day)))
            expect(storage.lastCursor(for: sensor)).to(equal(now.addingTimeInterval(-day)))
        }

        it("stops after the empty streak when the OS holds only 3 days — instead of grinding to the bound") {
            makeManager(retainedDays: 3)
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(mapper.callCount).toEventually(equal(2 + stop), timeout: .seconds(5))
            expect(storage.lastCursor(for: sensor)).to(equal(now.addingTimeInterval(-day)))
        }

        it("persists and reports the deepest productive window (measured OS retention, AC8)") {
            makeManager(retainedDays: 3)
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(storage.deepestProductiveWindowStart(for: sensor))
                .toEventually(equal(now.addingTimeInterval(-3 * day)), timeout: .seconds(5))
            let deepestEvents = analytics.trackedEvents.filter {
                if case .sensorDeepestWindow = $0 { return true }
                return false
            }
            expect(deepestEvents).toNot(beEmpty())
        }

        it("aborts on a fetch failure without writing any cursor, so the next cycle re-probes (AC4)") {
            makeManager(retainedDays: 3)
            mapper.failEverything = true
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(mapper.callCount).toEventually(equal(1), timeout: .seconds(5))
            expect(storage.lastCursor(for: sensor)).toAlways(beNil(), until: .milliseconds(300))
        }

        it("never fetches before the consent bound even when every window has data") {
            makeManager(retainedDays: 500)
            clearance.enrollmentDate = now.addingTimeInterval(-4 * day)
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            // 3 planned windows [-4d, -1d), all productive, probed newest-first — then the bound.
            expect(mapper.callCount).toEventually(equal(3), timeout: .seconds(5))
            expect(mapper.earliestFrom).toNot(beNil())
            // The widened continuous fetch reaches at most epsilon past the oldest window start.
            expect(mapper.earliestFrom)
                .to(beGreaterThanOrEqualTo(now.addingTimeInterval(-4 * day - 1)))
            expect(storage.lastCursor(for: sensor)).to(equal(now.addingTimeInterval(-day)))
        }
    }
}

// MARK: - FUAM-3945 (AC4): the cursor moves only past durably handled windows

class SensorCursorDurabilitySpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let sensor = SRSensor.deviceUsageReport
        let now = SensorSampleUploadManager.utcDayStart(Date())
        let joinDay = now.addingTimeInterval(-30 * day)
        let head = now.addingTimeInterval(-4 * day)

        var storage: FakeSensorStorage!
        var clearance: FakeSensorClearance!
        var analytics: CapturingAnalyticsService!
        var mapper: RecordingDeviceMapper!
        var manager: SensorSampleUploadManager!

        beforeEach {
            storage = FakeSensorStorage()
            clearance = FakeSensorClearance()
            clearance.enrollmentDate = joinDay
            analytics = CapturingAnalyticsService()
            mapper = RecordingDeviceMapper()
            manager = SensorSampleUploadManager(withSensors: [sensor],
                                                storage: storage,
                                                reachability: FakeSensorReachability(),
                                                analytics: analytics,
                                                mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance
            // A cursor resume with the rescan already burnt for today: the plain forward walk.
            storage.setLastCursor(head, for: sensor)
            storage.setLastRescanDay(SensorSampleUploadManager.utcDayStart(now), for: sensor)
        }

        func origins() -> [String] {
            return analytics.trackedEvents.compactMap { event in
                if case let .sensorDataBackfillReach(_, _, boundedBy) = event { return boundedBy }
                return nil
            }
        }

        it("does not move the cursor on a fetch error") {
            mapper.failingDeviceKeys = [SensorDevice.iphoneKey]
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(mapper.calls.count).toEventually(equal(1), timeout: .seconds(5))
            expect(storage.lastCursor(for: sensor)).toAlways(equal(head), until: .milliseconds(300))
        }

        it("advances past a CONFIRMED-EMPTY window, and says so in telemetry") {
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                 timeout: .seconds(5))
            let empties: [(String, String)] = analytics.trackedEvents.compactMap { event in
                if case let .sensorWindowEmpty(_, _, windowDay, pass) = event { return (windowDay, pass) }
                return nil
            }
            expect(empties.count).to(equal(3))
            expect(Set(empties.map { $0.1 })).to(equal(["first"]))
        }

        it("does not move the cursor when the enqueue fails, and reports enqueue_failed") {
            storage.failEnqueue = true
            mapper.records = [["t": ISO8601DateFormatter().string(from: head.addingTimeInterval(hour))]]
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(origins()).toEventually(contain(BackfillLowerBound.Origin.enqueueFailed.rawValue),
                                           timeout: .seconds(5))
            expect(storage.lastCursor(for: sensor)).toAlways(equal(head), until: .milliseconds(300))
        }

        it("advances past a window whose records were all deliberately consent-dropped, reporting the drop") {
            mapper.records = [["t": ISO8601DateFormatter().string(from: joinDay.addingTimeInterval(-day))]]
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                 timeout: .seconds(5))
            let drops = analytics.trackedEvents.filter {
                if case .sensorRecordDropped = $0 { return true }
                return false
            }
            expect(drops).toNot(beEmpty())
            expect(storage.enqueued).to(beEmpty())
        }

        it("labels an empty rescan window as a rescan pass") {
            let window = DateInterval(start: now.addingTimeInterval(-3 * day), end: now.addingTimeInterval(-2 * day))
            let context = SensorSampleUploadManager.DeviceChainContext(sensor: sensor,
                                                                       device: .current,
                                                                       devices: [.current],
                                                                       deviceIndex: 0,
                                                                       now: now,
                                                                       mapper: mapper,
                                                                       plannedBound: joinDay,
                                                                       rescanBoundary: now.addingTimeInterval(-day))
            manager.handleWindowResult(.success([]), window: window, at: 0, of: [window], context: context)

            let passes: [String] = analytics.trackedEvents.compactMap { event in
                if case let .sensorWindowEmpty(_, _, _, pass) = event { return pass }
                return nil
            }
            expect(passes).toEventually(equal(["rescan_3"]), timeout: .seconds(5))
        }
    }
}

/// A mapper whose per-window result is decided by a closure over the (widened) fetch span.
private final class ClosureDeviceMapper: SensorSampleMapper {

    private let lock = NSLock()
    private var count = 0
    private var earliest: Date?
    private let recordsForWindow: (Date, Date) -> [[String: Any]]

    var failEverything = false

    var callCount: Int { return self.lock.locked { self.count } }
    var earliestFrom: Date? { return self.lock.locked { self.earliest } }

    init(recordsForWindow: @escaping (Date, Date) -> [[String: Any]]) {
        self.recordsForWindow = recordsForWindow
    }

    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        self.lock.locked {
            self.count += 1
            if self.earliest == nil || from < self.earliest! { self.earliest = from }
        }
        if self.failEverything {
            completion(.failure(NSError(domain: "spec.mapper", code: 1)))
        } else {
            completion(.success(self.recordsForWindow(from, to)))
        }
    }
}

// MARK: - FUAM-3945 round 9 (F1 rev 2, H2.5): per-mapper recorded_at anchor guard

/// The backend derives each row's semantic anchor as `min(records[].recorded_at)` with a STRICT,
/// offset-requiring ISO8601 parse — and silently falls back to UPLOAD time when nothing parses,
/// quietly corrupting the row's position in history. These specs pin, mapper by mapper, that the
/// emitted `recorded_at` exists and parses strictly. The KVC-based mapping seams are exercised
/// with stand-ins named to satisfy each mapper's type guard; the CoreMotion-backed mappers
/// (pedometer, accelerometer) pass `recorded_at` through verbatim from `ISO8601Strategy.encode`,
/// whose format is pinned here and in `SensorRecordedAtSpec`.
class SensorRecordedAtAnchorGuardSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        // 2026-08-10 12:00:00.500 UTC — deliberately not on a whole second.
        let recordedAt = Date(timeIntervalSince1970: 1786363200.5)
        let recordedAtISO = ISO8601Strategy.encode(recordedAt)

        /// The backend's parse, mirrored: internet date-time WITH a mandatory offset, in the
        /// plain and the fractional-seconds variants.
        func strictOffsetParse(_ string: String?) -> Date? {
            guard let string = string else { return nil }
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return plain.date(from: string) ?? fractional.date(from: string)
        }

        it("device usage report: recorded_at present and strictly parsable") {
            let record = DeviceUsageReportMapper.mapDeviceUsage(FakeDeviceUsageReportSample(), recordedAt: recordedAt)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("phone usage report: recorded_at present and strictly parsable") {
            let record = PhoneUsageReportMapper.mapPhoneUsage(FakePhoneUsageReportSample(), recordedAt: recordedAt)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("messages usage report: recorded_at present and strictly parsable") {
            let record = MessagesUsageReportMapper.mapMessagesUsage(FakeMessagesUsageReportSample(), recordedAt: recordedAt)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("keyboard metrics: recorded_at present and strictly parsable") {
            let record = KeyboardMetricsMapper.mapKeyboardMetrics(FakeKeyboardMetricsSample(), recordedAt: recordedAt)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("visits: recorded_at present and strictly parsable") {
            let record = VisitsMapper.mapVisit(FakeSRVisitSample(), recordedAt: recordedAt)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("media events: recorded_at present and strictly parsable") {
            guard #available(iOS 16.4, *) else { return }
            let record = MediaEventsMapper.mapMediaEvent(FakeSRMediaEventSample(), recordedAtISO: recordedAtISO)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("ambient light: recorded_at present and strictly parsable") {
            let sample = FakeAnchorAmbientLightSample(startDate: recordedAt.addingTimeInterval(-3600))
            let record = AmbientLightMapper.mapAmbientLight(sample, recordedAtISO: recordedAtISO)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("ambient pressure: recorded_at present and strictly parsable") {
            let sample = FakeAnchorAmbientPressureSample(timestamp: recordedAt.addingTimeInterval(-3600))
            let record = AmbientPressureMapper.mapAmbientPressure(sample, recordedAtISO: recordedAtISO)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("rotation rate: recorded_at present and strictly parsable") {
            let sample = FakeAnchorRotationSample(startDate: recordedAt.addingTimeInterval(-3600))
            let record = RotationRateMapper.mapRotationSample(sample, recordedAtISO: recordedAtISO)
            expect(strictOffsetParse(record?["recorded_at"] as? String)).toNot(beNil())
        }

        it("both ISO encodings in use (whole-second and fractional) parse under the strict rule") {
            // The five report mappers emit whole seconds (plain ISO8601DateFormatter); the
            // FUAM-4013 continuous mappers, pedometer and accelerometer emit fractional seconds
            // (ISO8601Strategy.encode). Both must stay offset-bearing.
            expect(strictOffsetParse(ISO8601DateFormatter().string(from: recordedAt))).toNot(beNil())
            expect(strictOffsetParse(ISO8601Strategy.encode(recordedAt))).toNot(beNil())
        }
    }
}

// KVC stand-ins named to satisfy each mapper's `NSStringFromClass(...).contains(...)` guard.
// Every field the mappers read is optional except the type name, so bare objects suffice.
private final class FakeDeviceUsageReportSample: NSObject {}
private final class FakePhoneUsageReportSample: NSObject {}
private final class FakeMessagesUsageReportSample: NSObject {}
private final class FakeKeyboardMetricsSample: NSObject {}
// The visits and media-events mappers drop records with no substantive field beyond
// `recorded_at`, so these two carry one readable field each.
private final class FakeSRVisitSample: NSObject {
    @objc let distanceFromHome: Double = 120
}
private final class FakeSRMediaEventSample: NSObject {
    @objc let mediaIdentifier: String = "media-1"
    @objc let eventType: NSNumber = 1
}

private final class FakeAnchorAmbientLightSample: NSObject {
    @objc let startDate: Date
    @objc let lux: Double = 42
    init(startDate: Date) { self.startDate = startDate }
}

private final class FakeAnchorAmbientPressureSample: NSObject {
    @objc let timestamp: Date
    @objc let pressure: NSNumber = 101.3
    init(timestamp: Date) { self.timestamp = timestamp }
}

private final class FakeAnchorRotationSample: NSObject {
    @objc let startDate: Date
    // swiftlint:disable identifier_name
    @objc let x: Double = 0.1
    @objc let y: Double = 0.2
    @objc let z: Double = 0.3
    // swiftlint:enable identifier_name
    init(startDate: Date) { self.startDate = startDate }
}

// MARK: - FUAM-3945 (C1 item 7 / AC5): the plain-query walk and the proactive payload split

/// H3: the anchored-query path is REMOVED from the walk by type — `HealthSampleUploader.run` and
/// the `uploadChunk` seam can no longer express an anchored fetch. H4: the one predicate the walk
/// owns is `.strictStartDate`, so a boundary-straddling sample belongs to exactly one chunk.
/// AC5: payloads are sized as the batch is built and split proactively at the margin —
/// deterministically, so a reinstall reproduces the same chunks and the same anchors (AC2).
class HealthChunkQuerySpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let start = Date(timeIntervalSince1970: 1_786_000_000)
        let end = start.addingTimeInterval(3600)

        func sample(at date: Date, padding: Int = 0) -> HKQuantitySample? {
            guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
            let metadata: [String: Any]? = padding > 0
                ? [HKMetadataKeyExternalUUID: String(repeating: "x", count: padding)]
                : nil
            return HKQuantitySample(type: type,
                                    quantity: HKQuantity(unit: .count(), doubleValue: 1),
                                    start: date,
                                    end: date,
                                    metadata: metadata)
        }

        describe("chunkPredicate (H4)") {

            it("is the strict-start-date predicate, byte for byte") {
                let expected = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
                expect(HealthSampleUploader.chunkPredicate(startDate: start, endDate: end).predicateFormat)
                    == expected.predicateFormat
            }

            it("is NOT the default overlap predicate that returned boundary samples twice") {
                let overlap = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
                expect(HealthSampleUploader.chunkPredicate(startDate: start, endDate: end).predicateFormat)
                    .toNot(equal(overlap.predicateFormat))
            }
        }

        describe("deterministicallyOrdered (AC2)") {

            it("orders same-start samples by uuid, whatever order they arrived in") {
                guard let one = sample(at: start), let two = sample(at: start), let three = sample(at: start) else {
                    return fail("no step count type")
                }
                let forward = HealthSampleUploader.deterministicallyOrdered([one, two, three])
                let backward = HealthSampleUploader.deterministicallyOrdered([three, two, one])
                expect(forward.map { $0.uuid }).to(equal(backward.map { $0.uuid }))
            }
        }

        describe("proactiveChunks (AC5)") {

            let dataType = HealthDataType.stepCount

            it("splits a batch straddling the margin into chunks that all fit, losing nothing") {
                let samples = (0..<8).compactMap { sample(at: start.addingTimeInterval(TimeInterval($0)), padding: 400) }
                guard samples.count == 8 else { return fail("no step count type") }
                let margin = 2500
                guard let chunks = HealthSampleUploader.proactiveChunks(of: samples,
                                                                        forDataType: dataType,
                                                                        marginBytes: margin) else {
                    return fail("splittable batch reported as unsplittable")
                }
                expect(chunks.count).to(beGreaterThan(1))
                for chunk in chunks {
                    let bytes = HealthSampleUploader.serializedSize(of: chunk.getNetworkData(forDataType: dataType))
                    expect(bytes ?? 0).to(beLessThanOrEqualTo(margin))
                }
                expect(chunks.flatMap { $0 }.map { $0.uuid }).to(equal(samples.map { $0.uuid }))
            }

            it("produces the same split for the same input, twice (AC2)") {
                let samples = (0..<8).compactMap { sample(at: start.addingTimeInterval(TimeInterval($0)), padding: 400) }
                guard samples.count == 8 else { return fail("no step count type") }
                let first = HealthSampleUploader.proactiveChunks(of: samples, forDataType: dataType, marginBytes: 2500)
                let second = HealthSampleUploader.proactiveChunks(of: samples, forDataType: dataType, marginBytes: 2500)
                expect(first?.map { $0.count }).to(equal(second?.map { $0.count }))
                expect(first?.map { chunk in chunk.map { $0.uuid } }).to(equal(second?.map { chunk in chunk.map { $0.uuid } }))
            }

            it("reports a single sample that cannot fit alone as a hard error, never a silent drop") {
                guard let oversize = sample(at: start, padding: 4000) else { return fail("no step count type") }
                expect(HealthSampleUploader.proactiveChunks(of: [oversize], forDataType: dataType, marginBytes: 2500))
                    .to(beNil())
            }

            it("leaves a batch under the margin whole") {
                let samples = (0..<3).compactMap { sample(at: start.addingTimeInterval(TimeInterval($0))) }
                guard samples.count == 3 else { return fail("no step count type") }
                let chunks = HealthSampleUploader.proactiveChunks(of: samples,
                                                                  forDataType: dataType,
                                                                  marginBytes: Constants.HealthKit.MaxUploadPayloadBytes)
                expect(chunks?.count).to(equal(1))
                expect(chunks?.first?.count).to(equal(3))
            }
        }
    }
}

// MARK: - FUAM-3945: probe-order consent guard (the widened fetch must never over-vouch)

/// The backward probe walks newest-first, so a widened report fetch returns records BEFORE their
/// own window is reached; vouching an undecidable record on the newer window's start would let a
/// pre-join report through at the join boundary. The probe therefore vouches on the widened
/// span's start — conservative, never generous (AC6).
class SensorProbeVouchGuardSpec: QuickSpec {

    override class func spec() {

        let day: TimeInterval = 24 * 3600
        let sensor = SRSensor.deviceUsageReport
        let now = SensorSampleUploadManager.utcDayStart(Date())

        it("drops an undecidable report record at the join boundary during the probe") {
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = now.addingTimeInterval(-3 * day)   // two planned windows
            let analytics = CapturingAnalyticsService()
            let mapper = RecordingDeviceMapper()
            // No readable measurement time: only the vouch can save it. Pre-fix, the probe's
            // newest window ([-2d, -1d), start > bound) vouched for it and uploaded a record
            // that may describe the pre-join day.
            mapper.records = [["payload": "opaque"]]
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: analytics,
                                                    mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance

            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)

            expect(mapper.calls.count).toEventually(equal(2), timeout: .seconds(5))
            expect(storage.enqueued).toAlways(beEmpty(), until: .milliseconds(300))
            let drops = analytics.trackedEvents.filter {
                if case .sensorRecordDropped = $0 { return true }
                return false
            }
            expect(drops).toNot(beEmpty())
        }
    }
}

// MARK: - Review round 1, F1: window membership under the widened fetch

/// The harness gap the round-1 review named: every fake ignored the requested span, so the
/// containment behaviour that motivates the widen was unmodeled and F1 was invisible. This
/// mapper honours it — a report is returned iff its whole period fits the span (`from`
/// exclusive, `to` inclusive), which is the evidenced SensorKit selection semantics.
private final class ContainmentReportMapper: SensorSampleMapper {

    struct Report {
        let start: Date
        let duration: TimeInterval
        let record: [String: Any]
    }

    var reports: [Report] = []

    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        let contained = reports
            .filter { $0.start > from && $0.start.addingTimeInterval($0.duration) <= to }
            .map { $0.record }
        completion(.success(contained))
    }
}

/// F1: the widened fetch of probe window W returns the previous day's report before that day's
/// window has run; without the membership filter both days land in ONE batch anchored a day low
/// — a permanently rowless newest day on fresh installs, and probe batches that differ from the
/// forward walk's (order-dependent composition, AC2 violated).
class SensorProbeWindowBindingSpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let sensor = SRSensor.phoneUsageReport
        let now = SensorSampleUploadManager.utcDayStart(Date())

        func dailyReports(days: ClosedRange<Int>) -> [ContainmentReportMapper.Report] {
            return days.map { age in
                let start = now.addingTimeInterval(TimeInterval(-age) * day)
                let iso = ISO8601DateFormatter()
                return ContainmentReportMapper.Report(
                    start: start,
                    duration: day,
                    record: ["start": iso.string(from: start),
                             "duration_s": day,
                             "recorded_at": iso.string(from: start.addingTimeInterval(day - 1))])
            }
        }

        func runWalk(joinDay: Date, cursor: Date?) -> [(records: [[String: Any]], windowStart: Date)] {
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = joinDay
            let mapper = ContainmentReportMapper()
            mapper.reports = dailyReports(days: 2...5)
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: CapturingAnalyticsService(),
                                                    mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance
            if let cursor = cursor {
                storage.setLastCursor(cursor, for: sensor)
                // Pre-burn the rescan so the forward walk is a plain cursor resume.
                storage.setLastRescanDay(SensorSampleUploadManager.utcDayStart(now), for: sensor)
            }
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)
            expect(storage.enqueued.count).toEventually(beGreaterThan(0), timeout: .seconds(5))
            // Wait for the chain to finish: the cursor parks at the plan head on every path.
            expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                 timeout: .seconds(5))
            return storage.enqueued
        }

        it("binds every probe batch to its OWN day — never the previous day's records (F1)") {
            // Fresh install: join day 5 days back, no cursor -> backward probe over 4 windows,
            // with a report available for every one of them.
            let batches = runWalk(joinDay: now.addingTimeInterval(-5 * day), cursor: nil)

            expect(batches.count).to(equal(4))
            for batch in batches {
                expect(batch.records.count).to(equal(1))
                let measured = SensorSampleUploadManager.measurementTime(of: batch.records[0], sensor: sensor)
                // The record's own day IS the batch's window: the anchor lands on the right day.
                expect(measured).to(equal(batch.windowStart))
            }
            // Including the NEWEST complete day, which the misbinding left permanently rowless.
            expect(batches.map { $0.windowStart }).to(contain(now.addingTimeInterval(-2 * day)))
        }

        it("produces the same per-day batches whichever direction the walk ran (AC2: order independence)") {
            // Forward: cursor resume from -5d (join day further back). Probe: fresh, join -5d.
            let forward = runWalk(joinDay: now.addingTimeInterval(-10 * day), cursor: now.addingTimeInterval(-5 * day))
            let probe = runWalk(joinDay: now.addingTimeInterval(-5 * day), cursor: nil)

            let forwardByDay = Dictionary(uniqueKeysWithValues: forward.map {
                ($0.windowStart, SensorUploadLedger.canonical(["records": $0.records]))
            })
            let probeByDay = Dictionary(uniqueKeysWithValues: probe.map {
                ($0.windowStart, SensorUploadLedger.canonical(["records": $0.records]))
            })
            expect(probeByDay).to(equal(forwardByDay))
        }

        it("binds PRODUCTION-shape reports — recorded_at + duration_s only, end−1s stamp — one per day (R2-3)") {
            // Prod usage reports expose no start date (window-loss report L262): the membership
            // rule runs on the DERIVED period [recorded_at − duration_s, recorded_at], whose
            // start sits 1s before the report's own window. This pins the derived path the
            // friendly fixtures above cannot reach.
            let iso = ISO8601DateFormatter()
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = now.addingTimeInterval(-6 * day)
            let mapper = ContainmentReportMapper()
            mapper.reports = (2...5).map { age -> ContainmentReportMapper.Report in
                let start = now.addingTimeInterval(TimeInterval(-age) * day)
                return ContainmentReportMapper.Report(
                    start: start,
                    duration: day,
                    record: ["duration_s": day,
                             "recorded_at": iso.string(from: start.addingTimeInterval(day - 1))])
            }
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: CapturingAnalyticsService(),
                                                    mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance

            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)
            expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                 timeout: .seconds(5))

            let batches = storage.enqueued
            expect(batches.count).to(equal(4))
            for batch in batches {
                expect(batch.records.count).to(equal(1))
                guard let stamp = batch.records.first?["recorded_at"] as? String,
                      let recordedAt = iso.date(from: stamp) else {
                    fail("unreadable recorded_at in \(batch.records)")
                    continue
                }
                // The report landed on its OWN day's window.
                expect(recordedAt).to(beGreaterThanOrEqualTo(batch.windowStart))
                expect(recordedAt).to(beLessThan(batch.windowStart.addingTimeInterval(day)))
            }
        }
    }
}

// MARK: - Review round 1, F4: the 26h widen closes the DST + diverging-device hole

/// A 25-hour device-local report day (fall-back) with the participant zone falling back on the
/// SAME date one zone east: under a 24h widen the placement interval for the period was 24h
/// against a 25h gap between participant midnights — a 1h hole, the day fit NO window on any of
/// its four passes. 26h closes it.
class SensorDstWidenSpec: QuickSpec {

    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let rome = TimeZone(identifier: "Europe/Rome")!
        let london = TimeZone(identifier: "Europe/London")!

        it("a London-device 25h fall-back day fits a Rome-participant window's widened span") {
            // 2026-10-28 12:00:00 UTC — three days after the shared EU fall-back (Oct 25 2026).
            let now = Date(timeIntervalSince1970: 1793188800)
            var romeCalendar = Calendar(identifier: .gregorian)
            romeCalendar.timeZone = rome
            var londonCalendar = Calendar(identifier: .gregorian)
            londonCalendar.timeZone = london

            let joinDay = romeCalendar.startOfDay(for: now.addingTimeInterval(-7 * day))
            let plan = SensorSampleUploadManager.buildWindowPlan(now: now,
                                                                 boundNow: now,
                                                                 joinDay: joinDay,
                                                                 cursor: nil,
                                                                 embargo: day,
                                                                 timeZone: rome)

            // The device-local reporting day: London's Oct 25 2026, which is 25 hours long.
            let fallBackNoon = Date(timeIntervalSince1970: 1792929600)   // 2026-10-25 12:00:00 UTC
            let periodStart = londonCalendar.startOfDay(for: fallBackNoon)
            guard let periodEnd = londonCalendar.date(byAdding: .day, value: 1, to: periodStart) else {
                return fail("calendar arithmetic failed")
            }
            expect(periodEnd.timeIntervalSince(periodStart)).to(equal(25 * hour))

            // Containment (`from` exclusive, `to` inclusive) against every window's widened span.
            let contained = plan.windows.contains { window in
                let span = SensorSampleUploadManager.fetchSpan(for: .phoneUsageReport, window: window)
                return periodStart > span.start && periodEnd <= span.end
            }
            expect(contained).to(beTrue())
        }
    }
}

// MARK: - Review round 1, F8: a gave-up window resets the probe's empty streak

/// AC1's stop criterion is K CONSECUTIVE confirmed-empty windows. An unread (gave-up) window is
/// UNKNOWN, not empty: letting the streak survive it allowed two empties separated by a failure
/// to stop the probe, forfeiting everything older on weaker evidence than specified.
class SensorProbeStreakResetSpec: QuickSpec {

    override class func spec() {

        let day: TimeInterval = 24 * 3600
        let sensor = SRSensor.pedometerData
        let now = SensorSampleUploadManager.utcDayStart(Date())

        it("keeps probing past a gave-up window instead of counting it toward the empty streak") {
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = now.addingTimeInterval(-6 * day)
            // Windows newest-first: [-2,-1) empty, [-3,-2) FAILS (three cycles -> gave up),
            // then [-4,-3) and [-5,-4) empty. With the streak reset the probe must read BOTH
            // of them to satisfy K=2; with the carried-over streak it stopped one window early.
            let failingStart = now.addingTimeInterval(-3 * day)
            let failing = WindowFailingMapper(failingWindowStart: failingStart)
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: CapturingAnalyticsService(),
                                                    mappers: [sensor: failing])
            manager.clearanceDelegate = clearance

            // Cycle 1 and 2: the failing window aborts the probe (attempts 1 and 2), no cursor.
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: failing)
            expect(failing.failureCount).toEventually(equal(1), timeout: .seconds(5))
            expect(storage.lastCursor(for: sensor)).to(beNil())
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: failing)
            expect(failing.failureCount).toEventually(equal(2), timeout: .seconds(5))

            // Cycle 3: attempts exhaust -> gave_up -> the probe must CONTINUE and read two more
            // confirmed-empty windows before stopping.
            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: failing)

            expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                 timeout: .seconds(5))
            // The window BELOW the gave-up one was fetched: the streak did not carry over.
            expect(failing.fetchedWindowEnds).to(contain(now.addingTimeInterval(-4 * day)))
        }
    }
}

/// Fails every fetch of one specific window; every other window succeeds empty.
private final class WindowFailingMapper: SensorSampleMapper {

    private let lock = NSLock()
    private let failingWindowStart: Date
    private var failures = 0
    private var windowEnds: [Date] = []

    init(failingWindowStart: Date) {
        self.failingWindowStart = failingWindowStart
    }

    var failureCount: Int { return self.lock.locked { self.failures } }
    var fetchedWindowEnds: [Date] { return self.lock.locked { self.windowEnds } }

    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        // `from` is the widened span start (continuous epsilon = 1s); `to` is the narrow end.
        let windowStart = from.addingTimeInterval(1)
        let isFailing = abs(windowStart.timeIntervalSince(self.failingWindowStart)) < 0.5
        self.lock.locked {
            self.windowEnds.append(to)
            if isFailing { self.failures += 1 }
        }
        if isFailing {
            completion(.failure(NSError(domain: "spec.mapper", code: 7)))
        } else {
            completion(.success([]))
        }
    }
}

// MARK: - Round 3, R2-1: only a trustworthy period may drive probe deferral

/// `SRKeyboardMetrics.duration` is cumulative typing time, not a report period —
/// `measurementTime` already refuses it, and the probe's membership rule must agree: a
/// (hypothetical future) keyboard record exposing a start date computes a period end far short
/// of the true day-long period, false-passes containment, and is deferred into the no-window
/// loss class. Keeping it is the never-lossy direction.
class SensorProbeDeferralPeriodSpec: QuickSpec {

    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let now = SensorSampleUploadManager.utcDayStart(Date())
        let window = DateInterval(start: now.addingTimeInterval(-2 * day), end: now.addingTimeInterval(-day))
        let olderWindow = DateInterval(start: now.addingTimeInterval(-3 * day), end: now.addingTimeInterval(-2 * day))

        it("never defers a keyboard record on its cumulative duration") {
            let iso = ISO8601DateFormatter()
            // Start inside the older window, tiny cumulative typing time: containment against
            // the older span would false-pass if the duration were trusted as a period.
            let record: [String: Any] = ["start": iso.string(from: olderWindow.start.addingTimeInterval(hour)),
                                         "duration_s": 900,
                                         "recorded_at": iso.string(from: olderWindow.start.addingTimeInterval(2 * hour))]
            expect(SensorSampleUploadManager.belongsToOlderProbeWindow(record,
                                                                       sensor: .keyboardMetrics,
                                                                       window: window,
                                                                       olderWindow: olderWindow)).to(beFalse())
        }

        it("still defers the same shape for a usage report, whose duration IS the period") {
            let iso = ISO8601DateFormatter()
            let record: [String: Any] = ["start": iso.string(from: olderWindow.start.addingTimeInterval(hour)),
                                         "duration_s": 900,
                                         "recorded_at": iso.string(from: olderWindow.start.addingTimeInterval(2 * hour))]
            expect(SensorSampleUploadManager.belongsToOlderProbeWindow(record,
                                                                       sensor: .deviceUsageReport,
                                                                       window: window,
                                                                       olderWindow: olderWindow)).to(beTrue())
        }
    }
}

// MARK: - Round 4: the probe enqueues chronologically (discovery order decoupled from upload order)

/// The backward probe still DISCOVERS newest-first (that is what finds the OS retention horizon
/// without fetching hundreds of empty windows) but buffers each window and ENQUEUES oldest-first
/// at termination, so no code path enqueues out of chronological order and the D4 ledger — not
/// walk order — owns the cross-window dedup everywhere. Past the buffer cap the probe flushes
/// early and falls back to enqueue-as-you-go (the pre-round-4 regime): still the same batches,
/// telemetered, just not strictly chronological.
class SensorProbeChronologySpec: QuickSpec {

    // swiftlint:disable:next function_body_length
    override class func spec() {

        let hour: TimeInterval = 3600
        let day: TimeInterval = 24 * hour
        let now = SensorSampleUploadManager.utcDayStart(Date())
        let iso = ISO8601DateFormatter()

        it("enqueues probe windows OLDEST-first even though discovery walks newest-first") {
            let sensor = SRSensor.pedometerData
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = now.addingTimeInterval(-5 * day)
            let mapper = ClosureDeviceMapper { _, to in
                [["t": iso.string(from: to.addingTimeInterval(-hour))]]
            }
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: CapturingAnalyticsService(),
                                                    mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance

            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)
            expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                 timeout: .seconds(5))

            // Discovery fetched [-2,-1) first; the queue must still read oldest-first.
            let starts = storage.enqueued.map { $0.windowStart }
            expect(starts).to(equal([now.addingTimeInterval(-5 * day),
                                     now.addingTimeInterval(-4 * day),
                                     now.addingTimeInterval(-3 * day),
                                     now.addingTimeInterval(-2 * day)]))
        }

        it("the forward walk enqueues oldest-first too (no path enqueues out of chronological order)") {
            let sensor = SRSensor.pedometerData
            let storage = FakeSensorStorage()
            let clearance = FakeSensorClearance()
            clearance.enrollmentDate = now.addingTimeInterval(-30 * day)
            let mapper = ClosureDeviceMapper { _, to in
                [["t": iso.string(from: to.addingTimeInterval(-hour))]]
            }
            let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                    storage: storage,
                                                    reachability: FakeSensorReachability(),
                                                    analytics: CapturingAnalyticsService(),
                                                    mappers: [sensor: mapper])
            manager.clearanceDelegate = clearance
            // A plain cursor resume: cursor 5 days back, today's rescan already burnt.
            storage.setLastCursor(now.addingTimeInterval(-5 * day), for: sensor)
            storage.setLastRescanDay(SensorSampleUploadManager.utcDayStart(now), for: sensor)

            manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)
            expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                 timeout: .seconds(5))

            let starts = storage.enqueued.map { $0.windowStart }
            expect(starts).to(equal(starts.sorted()))
            expect(starts.count).to(equal(4))
        }

        it("past the buffer cap the probe falls back to enqueue-as-you-go and still produces IDENTICAL batches") {
            let sensor = SRSensor.phoneUsageReport

            func reports() -> [ContainmentReportMapper.Report] {
                return (2...5).map { age in
                    let start = now.addingTimeInterval(TimeInterval(-age) * day)
                    return ContainmentReportMapper.Report(
                        start: start,
                        duration: day,
                        record: ["start": iso.string(from: start),
                                 "duration_s": day,
                                 "recorded_at": iso.string(from: start.addingTimeInterval(day - 1))])
                }
            }

            func runProbe(bufferCap: Int?) -> (batches: [Date: String], analytics: CapturingAnalyticsService) {
                let storage = FakeSensorStorage()
                let clearance = FakeSensorClearance()
                clearance.enrollmentDate = now.addingTimeInterval(-5 * day)
                let analytics = CapturingAnalyticsService()
                let mapper = ContainmentReportMapper()
                mapper.reports = reports()
                let manager = SensorSampleUploadManager(withSensors: [sensor],
                                                        storage: storage,
                                                        reachability: FakeSensorReachability(),
                                                        analytics: analytics,
                                                        mappers: [sensor: mapper])
                manager.clearanceDelegate = clearance
                if let bufferCap = bufferCap {
                    manager.probeBufferMaxRecords = bufferCap
                }
                manager.runDeviceChain(at: 0, of: [.current], for: sensor, now: now, using: mapper)
                expect(storage.lastCursor(for: sensor)).toEventually(equal(now.addingTimeInterval(-day)),
                                                                     timeout: .seconds(5))
                let batches = Dictionary(uniqueKeysWithValues: storage.enqueued.map {
                    ($0.windowStart, SensorUploadLedger.canonical(["records": $0.records]))
                })
                return (batches, analytics)
            }

            // The widened report fetch makes the newest window buffer TWO records, so cap 1
            // trips the overflow on the very first window.
            let capped = runProbe(bufferCap: 1)
            let uncapped = runProbe(bufferCap: nil)

            expect(capped.batches).to(equal(uncapped.batches))
            expect(capped.batches.count).to(equal(4))

            func overflowOrigins(_ analytics: CapturingAnalyticsService) -> [String] {
                return analytics.trackedEvents.compactMap { event in
                    if case let .sensorDataBackfillReach(_, _, boundedBy) = event,
                       boundedBy == BackfillLowerBound.Origin.probeBufferOverflow.rawValue {
                        return boundedBy
                    }
                    return nil
                }
            }
            expect(overflowOrigins(capped.analytics)).toNot(beEmpty())
            expect(overflowOrigins(uncapped.analytics)).to(beEmpty())
        }
    }
}
