//
//  AppExitMetricsReporter.swift
//  ForYouAndMe
//
//  FUAM-4518. Asks MetricKit (once per delivered daily payload) how iOS
//  terminated the app, and records ONE Crashlytics non-fatal per payload,
//  always, even when every count is zero. That is what lets "no more
//  memory kills" be observed. Only counts and OS/build metadata are sent.
//
//  Availability (Apple SDK headers): MXMetricManager and its subscriber
//  protocol iOS 13, MXMetricPayload.applicationExitMetrics iOS 14. The pod
//  targets iOS 15.6, so no #available guard is needed. The SDK 27 headers
//  mark the shared manager "to be deprecated" without a replacement
//  available at our deployment target, so it is used as is.
//

import Foundation
import MetricKit
import FirebaseCrashlytics

/// Plain counts, so the report logic is testable (`MXMetricPayload` cannot be constructed).
struct AppExitCounts {
    /// Foreground counts keyed by the `fg_` names, background by the `bg_` names. Nil: payload had no exit metric.
    var foreground: [String: Int]?
    var background: [String: Int]?
    var peakMemoryMb: Int?
    var periodBegin: Date
    var periodEnd: Date
    var osVersion: String?
    var appBuild: String?
    var includesMultipleApplicationVersions: Bool
}

final class AppExitMetricsReporter: NSObject, MXMetricManagerSubscriber {

    static let errorDomain = "fyam.metrickit.app_exit"

    private static var started = false
    private static let shared = AppExitMetricsReporter()

    /// Idempotent: subscribes once per process.
    static func start() {
        guard !self.started else { return }
        self.started = true
        MXMetricManager.shared.add(self.shared)
    }

    // MARK: - Pure report

    struct Report {
        let customKeys: [String: Int]
        let errorCode: Int
        let userInfo: [String: Any]
    }

    static func exitReport(from counts: AppExitCounts) -> Report {
        let fg = counts.foreground ?? [:]
        let bg = counts.background ?? [:]
        // Code 1 only when a non-normal FOREGROUND exit count is above zero (memory limit, watchdog, abnormal,
        // bad access, illegal instruction). Background counts are routine system evictions: they are reported in
        // `userInfo` but never affect the code. "Normal app exit" is the only normal foreground count.
        let hasAbnormal = fg.contains { $0.key != "fg_normal" && $0.value > 0 }

        var keys: [String: Int] = [:]
        if counts.foreground != nil {
            keys["mx_fg_memory_limit_exits"] = fg["fg_memory_limit"] ?? 0
            keys["mx_fg_watchdog_exits"] = fg["fg_watchdog"] ?? 0
            keys["mx_fg_abnormal_exits"] = fg["fg_abnormal"] ?? 0
        }
        if let peak = counts.peakMemoryMb { keys["mx_peak_memory_mb"] = peak }

        var info: [String: Any] = [:]
        for (key, value) in fg { info[key] = value }
        for (key, value) in bg { info[key] = value }
        info["exit_metrics_present"] = counts.foreground != nil ? 1 : 0
        if let peak = counts.peakMemoryMb { info["peak_memory_mb"] = peak }
        let formatter = ISO8601DateFormatter()
        info["period_begin"] = formatter.string(from: counts.periodBegin)
        info["period_end"] = formatter.string(from: counts.periodEnd)
        if let os = counts.osVersion { info["os_version"] = os }
        if let build = counts.appBuild { info["app_build"] = build }
        info["includes_multiple_app_versions"] = counts.includesMultipleApplicationVersions ? 1 : 0

        return Report(customKeys: keys, errorCode: hasAbnormal ? 1 : 0, userInfo: info)
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        Self.record(payloads.map { Self.counts(from: $0) })
    }

    /// Seam for specs: receives the error and the custom keys of each recorded report.
    static var recorder: (NSError, [String: Int]) -> Void = { error, keys in
        let crashlytics = Crashlytics.crashlytics()
        // Custom keys are process-wide in Crashlytics and are not cleared, so they can show the last payload's
        // values on other events of this process. The per-payload truth is `userInfo`; read counts from there.
        for (key, value) in keys { crashlytics.setCustomValue(value, forKey: key) }
        crashlytics.record(error: error)
    }

    /// ALWAYS records exactly one non-fatal per payload, even when every count is zero.
    static func record(_ payloads: [AppExitCounts]) {
        for counts in payloads {
            let report = self.exitReport(from: counts)
            self.recorder(NSError(domain: self.errorDomain, code: report.errorCode, userInfo: report.userInfo),
                          report.customKeys)
        }
    }

    private static func counts(from payload: MXMetricPayload) -> AppExitCounts {
        var foreground: [String: Int]?
        var background: [String: Int]?
        if let exits = payload.applicationExitMetrics {
            let fg = exits.foregroundExitData
            foreground = [
                "fg_normal": Int(fg.cumulativeNormalAppExitCount),
                "fg_memory_limit": Int(fg.cumulativeMemoryResourceLimitExitCount),
                "fg_watchdog": Int(fg.cumulativeAppWatchdogExitCount),
                "fg_abnormal": Int(fg.cumulativeAbnormalExitCount),
                "fg_bad_access": Int(fg.cumulativeBadAccessExitCount),
                "fg_illegal_instruction": Int(fg.cumulativeIllegalInstructionExitCount)
            ]
            let bgData = exits.backgroundExitData
            background = [
                "bg_normal": Int(bgData.cumulativeNormalAppExitCount),
                "bg_memory_limit": Int(bgData.cumulativeMemoryResourceLimitExitCount),
                "bg_cpu_limit": Int(bgData.cumulativeCPUResourceLimitExitCount),
                "bg_memory_pressure": Int(bgData.cumulativeMemoryPressureExitCount),
                "bg_watchdog": Int(bgData.cumulativeAppWatchdogExitCount),
                "bg_abnormal": Int(bgData.cumulativeAbnormalExitCount),
                "bg_bad_access": Int(bgData.cumulativeBadAccessExitCount),
                "bg_illegal_instruction": Int(bgData.cumulativeIllegalInstructionExitCount),
                "bg_suspended_locked_file": Int(bgData.cumulativeSuspendedWithLockedFileExitCount),
                "bg_task_assertion_timeout": Int(bgData.cumulativeBackgroundTaskAssertionTimeoutExitCount)
            ]
        }
        let peak = payload.memoryMetrics?.peakMemoryUsage.converted(to: .megabytes).value
        return AppExitCounts(foreground: foreground,
                             background: background,
                             peakMemoryMb: peak.map { Int($0.rounded()) },
                             periodBegin: payload.timeStampBegin,
                             periodEnd: payload.timeStampEnd,
                             osVersion: payload.metaData?.osVersion,
                             appBuild: payload.metaData?.applicationBuildVersion,
                             includesMultipleApplicationVersions: payload.includesMultipleApplicationVersions)
    }
}
