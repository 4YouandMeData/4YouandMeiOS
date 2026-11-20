//
//  AppExitMetricsReporterSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4518: Crashlytics user id wiring and the pure MetricKit exit report.
//

import Quick
import Nimble
@testable import ForYouAndMe

class AppExitMetricsReporterSpec: QuickSpec {
    override class func spec() {

        func counts(fg: [String: Int]? = ["fg_normal": 4, "fg_memory_limit": 0, "fg_watchdog": 0],
                    bg: [String: Int]? = ["bg_normal": 9, "bg_memory_limit": 0],
                    multi: Bool = false) -> AppExitCounts {
            return AppExitCounts(foreground: fg, background: bg, peakMemoryMb: 321,
                                 periodBegin: Date(timeIntervalSince1970: 0),
                                 periodEnd: Date(timeIntervalSince1970: 86400),
                                 osVersion: "iPhone OS 27.2", appBuild: "39",
                                 includesMultipleApplicationVersions: multi)
        }

        describe("crashlytics_user_id_follows_user_save_and_logout") {
            var recorded: [String?] = []
            let original = CrashlyticsSink.userIdSetter
            var storedUser: User?

            beforeEach {
                // The cache writes the test host's real UserDefaults: put the stored user back afterwards.
                storedUser = CacheManager().user
                recorded = []
                CrashlyticsSink.userIdSetter = { recorded.append($0) }
            }
            afterEach {
                CrashlyticsSink.userIdSetter = original
                CacheManager().user = storedUser
            }

            it("passes the id through, and nil clears it") {
                CrashlyticsSink.setUser(id: "807")
                CrashlyticsSink.setUser(id: nil)
                expect(recorded).to(equal(["807", nil]))
            }

            it("the cache user setter sets and clears the id") {
                let json = """
                {"id":"807","type":"user","email":"a@b.c","on_boarding_completed":true,"days_in_study":3,
                 "identities":[],"agreed_permissions":[],"study_walkthrough_done":true,"user_flags":[]}
                """
                let user = try JSONDecoder().decode(User.self, from: Data(json.utf8))
                let cache = CacheManager()
                cache.user = user
                cache.user = nil
                expect(recorded).to(equal(["807", nil]))
            }
        }

        describe("record_loop") {
            var recorded: [(NSError, [String: Int])] = []
            let original = AppExitMetricsReporter.recorder

            beforeEach {
                recorded = []
                AppExitMetricsReporter.recorder = { recorded.append(($0, $1)) }
            }
            afterEach { AppExitMetricsReporter.recorder = original }

            it("records exactly one non-fatal per payload, including all-zero ones: codes [0, 1, 0]") {
                AppExitMetricsReporter.record([counts(),
                                               counts(fg: ["fg_normal": 1, "fg_memory_limit": 1]),
                                               counts(fg: nil, bg: nil)])
                expect(recorded.map { $0.0.code }).to(equal([0, 1, 0]))
                expect(recorded.map { $0.0.domain }).to(equal(Array(repeating: "fyam.metrickit.app_exit", count: 3)))
            }
        }

        describe("exit_report_always_records_one_non_fatal_with_code_by_abnormality") {
            it("all zero abnormal counts: code 0, counts still present") {
                let report = AppExitMetricsReporter.exitReport(from: counts())
                expect(report.errorCode).to(equal(0))
                expect(report.customKeys["mx_fg_memory_limit_exits"]).to(equal(0))
                expect(report.customKeys["mx_peak_memory_mb"]).to(equal(321))
                expect(report.userInfo["fg_normal"] as? Int).to(equal(4))
                expect(report.userInfo["bg_normal"] as? Int).to(equal(9))
            }
            it("foreground memory limit: code 1") {
                let report = AppExitMetricsReporter.exitReport(from: counts(fg: ["fg_normal": 1, "fg_memory_limit": 2]))
                expect(report.errorCode).to(equal(1))
                expect(report.customKeys["mx_fg_memory_limit_exits"]).to(equal(2))
            }
            it("background-only abnormal exits never raise the code, but stay in userInfo") {
                let report = AppExitMetricsReporter.exitReport(
                    from: counts(bg: ["bg_normal": 1, "bg_memory_pressure": 2, "bg_task_assertion_timeout": 1,
                                      "bg_memory_limit": 1, "bg_watchdog": 1]))
                expect(report.errorCode).to(equal(0))
                expect(report.userInfo["bg_memory_pressure"] as? Int).to(equal(2))
                expect(report.userInfo["bg_task_assertion_timeout"] as? Int).to(equal(1))
            }
            it("foreground watchdog exit: code 1") {
                let report = AppExitMetricsReporter.exitReport(from: counts(fg: ["fg_normal": 1, "fg_watchdog": 1]))
                expect(report.errorCode).to(equal(1))
            }
            it("every non-normal foreground count raises the code") {
                for key in ["fg_memory_limit", "fg_watchdog", "fg_abnormal", "fg_bad_access", "fg_illegal_instruction"] {
                    let report = AppExitMetricsReporter.exitReport(from: counts(fg: ["fg_normal": 3, key: 1]))
                    expect(report.errorCode).to(equal(1), description: key)
                }
            }
            it("normal exits alone never raise the code") {
                let report = AppExitMetricsReporter.exitReport(from: counts(fg: ["fg_normal": 50], bg: ["bg_normal": 50]))
                expect(report.errorCode).to(equal(0))
            }
            it("carries range, OS, build and the multiple-versions flag, and nothing outside the documented keys") {
                let allFg = ["fg_normal", "fg_memory_limit", "fg_watchdog", "fg_abnormal", "fg_bad_access",
                             "fg_illegal_instruction"]
                let allBg = ["bg_normal", "bg_memory_limit", "bg_cpu_limit", "bg_memory_pressure", "bg_watchdog",
                             "bg_abnormal", "bg_bad_access", "bg_illegal_instruction", "bg_suspended_locked_file",
                             "bg_task_assertion_timeout"]
                let full = counts(fg: Dictionary(uniqueKeysWithValues: allFg.map { ($0, 1) }),
                                  bg: Dictionary(uniqueKeysWithValues: allBg.map { ($0, 1) }),
                                  multi: true)
                let info = AppExitMetricsReporter.exitReport(from: full).userInfo
                let allowed = Set(allFg + allBg + ["exit_metrics_present", "peak_memory_mb", "period_begin",
                                                    "period_end", "os_version", "app_build",
                                                    "includes_multiple_app_versions"])
                expect(Set(info.keys)).to(equal(allowed))
                expect(info["includes_multiple_app_versions"] as? Int).to(equal(1))
                expect(info["os_version"] as? String).to(equal("iPhone OS 27.2"))
                expect(info["app_build"] as? String).to(equal("39"))
                expect(info["period_begin"] as? String).to(equal("1970-01-01T00:00:00Z"))
                expect(info["period_end"] as? String).to(equal("1970-01-02T00:00:00Z"))
            }
            it("payload without exit metrics is flagged, not reported as zeros") {
                let report = AppExitMetricsReporter.exitReport(from: counts(fg: nil, bg: nil))
                expect(report.errorCode).to(equal(0))
                expect(report.userInfo["exit_metrics_present"] as? Int).to(equal(0))
                expect(report.customKeys["mx_fg_memory_limit_exits"]).to(beNil())
            }
        }
    }
}
