//
//  DeviceUsageReportMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit

private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

// MARK: - Mapper

/// Maps SensorKit SRDeviceUsageReport into JSON-ready dictionaries.
/// NOTE: authorization and startRecording() are handled elsewhere.
final class DeviceUsageReportMapper: NSObject, SensorSampleMapper {

    // The SRSensor this mapper owns
    var sensor: SRSensor { .deviceUsageReport }

    // Dedicated reader
    private let reader = SRSensorReader(sensor: .deviceUsageReport)

    // Current request state (single-flight: no concurrent fetch)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected = [[String: Any]]()

    // Apple embargoes the last ~24h of data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    // Mapper errors
    private enum MapperError: LocalizedError {
        case busy
        case notAuthorized(status: SRAuthorizationStatus)

        var errorDescription: String? {
            switch self {
            case .busy:
                return "Mapper is busy: a fetch is already in flight."
            case let .notAuthorized(status):
                return "SensorKit not authorized for deviceUsageReport. Status: \(status)."
            }
        }
    }

    // MARK: - SensorSampleMapper

    /// Fetches [from, to) honouring the 24h embargo and maps SRDeviceUsageReport.
    func fetchAndMap(
        from: Date,
        to: Date,
        device: SensorDevice,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        // Avoid a crash on concurrent requests
        guard pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Apply the cutoff: never read the last 24h
        // F10 (review round 1; wording corrected round 3): the best clock available, not the raw
        // device clock. An improvement, not immunity: ServerClock.now() is Date() + storedOffset,
        // so a rollback lowers BOTH operands until the next API response re-records the offset —
        // inside that gap the cutoff can still truncate the planned span (the manager would treat
        // the partial result as the whole window). The planner owns embargo policy; this stays as
        // defence in depth.
        let embargoCutoff = max(Date(), ServerClock.now()).addingTimeInterval(-Self.holdingPeriod)
        let safeTo = min(to, embargoCutoff)
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        // Build the SRFetchRequest
        let req = SRFetchRequest()
        // FUAM-3945: iPhone or paired Watch — the manager walks one device at a time.
        req.device = device.fetchTarget
        req.from = from.srAbsoluteTime
        req.to = safeTo.srAbsoluteTime

        collected.removeAll(keepingCapacity: true)
        pendingCompletion = completion
        reader.delegate = self
        reader.fetch(req)
    }
}

// MARK: - SRSensorReaderDelegate

extension DeviceUsageReportMapper: SRSensorReaderDelegate {

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        didFetchResult result: SRFetchResult<AnyObject>
    ) -> Bool {
        // Attach SRFetchResult.timestamp
        let recordedAt = dateFromSRAbsoluteTime(result.timestamp)

        // Aggregated report (not a CMSensorDataList)
        if let obj = result.sample as? NSObject,
           let rec = Self.mapDeviceUsage(obj, recordedAt: recordedAt) {
            collected.append(rec)
        }
        return true // keep fetching
    }

    func sensorReader(_ reader: SRSensorReader, didCompleteFetch fetchRequest: SRFetchRequest) {
        finish(.success(collected))
    }

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        failedWithError error: Error
    ) {
        finish(.failure(error))
    }

    // Cleanup + callback
    private func finish(_ result: Result<[[String: Any]], Error>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        reader.delegate = nil
        completion?(result)
    }
}

// MARK: - Mapping (documented keys only, safe-KVC)

// Internal (was private): the per-mapper recorded_at anchor-guard specs exercise the mapping
// seams with KVC stand-ins (FUAM-3945 round 9, F1: a mapper regression dropping recorded_at
// silently degrades the server row anchor to upload time).
extension DeviceUsageReportMapper {

    // Safe KVC: only calls value(forKey:) when the selector exists
    static func valueIfResponds(_ obj: NSObject, _ key: String) -> Any? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return nil }
        return obj.value(forKey: key)
    }

    static func kvcDate(_ obj: NSObject, key: String) -> Date? {
        valueIfResponds(obj, key) as? Date
    }

    static func intValue(_ obj: NSObject, key: String) -> Int? {
        (valueIfResponds(obj, key) as? NSNumber)?.intValue
    }

    /// Extract seconds from either Measurement<UnitDuration> or numeric TimeInterval.
    static func seconds(_ obj: NSObject, key: String) -> Double? {
        if let m = valueIfResponds(obj, key) as? Measurement<UnitDuration> {
            return m.converted(to: .seconds).value
        }
        if let n = valueIfResponds(obj, key) as? NSNumber {
            return n.doubleValue
        }
        return nil
    }

    static func isDeviceUsageObject(_ obj: NSObject) -> Bool {
        let name = NSStringFromClass(type(of: obj))
        return name.contains("DeviceUsageReport")
    }

    /// FUAM-3945 fidelity audit, X5: symbolic name for a `SRDeviceUsageReport.NotificationUsage
    /// .Event` raw value. Built by switching on the SDK enum cases, so the raw-value table is
    /// the compiler's, not a hardcoded copy. Unlisted raw values (future OS cases) fall through
    /// `@unknown default` and yield `nil` — the numeric `event` key still carries them.
    static func notificationEventName(rawValue: Int) -> String? {
        guard let event = SRDeviceUsageReport.NotificationUsage.Event(rawValue: rawValue) else { return nil }
        switch event {
        case .unknown: return "unknown"
        case .received: return "received"
        case .defaultAction: return "default_action"
        case .supplementaryAction: return "supplementary_action"
        case .clear: return "clear"
        case .notificationCenterClearAll: return "notification_center_clear_all"
        case .removed: return "removed"
        case .hide: return "hide"
        case .longLook: return "long_look"
        case .silence: return "silence"
        case .appLaunch: return "app_launch"
        case .expired: return "expired"
        case .bannerPulldown: return "banner_pulldown"
        case .tapCoalesce: return "tap_coalesce"
        case .deduped: return "deduped"
        case .deviceActivated: return "device_activated"
        case .deviceUnlocked: return "device_unlocked"
        @unknown default: return nil
        }
    }

    static func categoryName(_ any: Any) -> String {
        // Try rawValue if it's an enum bridged to ObjC; fallback to description
        if let o = any as? NSObject,
           let raw = valueIfResponds(o, "rawValue") as? String {
            return raw
        }
        return String(describing: any)
    }

    // MARK: Top-level mapping

    static func mapDeviceUsage(_ obj: NSObject, recordedAt: Date?) -> [String: Any]? {
        guard isDeviceUsageObject(obj) else { return nil }
        let iso = ISO8601DateFormatter()
        var rec: [String: Any] = [:]

        // Timestamps
        if let ts = recordedAt {
            // `recorded_at` stays whole-second verbatim: the server derives every row anchor
            // from it and historical rows are whole-second (FUAM-3945 fidelity audit, X6).
            rec["recorded_at"] = iso.string(from: ts)
            // X6: the additive full-precision companion — fractional-seconds ISO8601, the one
            // dialect every NEW timestamp key standardises on.
            rec["recorded_at_precise"] = ISO8601Strategy.encode(ts)
        }
        if let start = kvcDate(obj, key: "startDate") { rec["start"] = iso.string(from: start) }
        if let end = kvcDate(obj, key: "endDate") { rec["end"] = iso.string(from: end) }

        // ---- Documented aggregate metrics (flat) ----
        if let d = seconds(obj, key: "duration") { rec["duration_s"] = d }                 // duration :contentReference[oaicite:5]{index=5}
        if let n = intValue(obj, key: "totalScreenWakes") { rec["total_screen_wakes"] = n } // totalScreenWakes :contentReference[oaicite:6]{index=6}
        if let n = intValue(obj, key: "totalUnlocks") { rec["total_unlocks"] = n }          // totalUnlocks :contentReference[oaicite:7]{index=7}
        if let s = seconds(obj, key: "totalUnlockDuration") { rec["total_unlock_duration_s"] = s } // totalUnlockDuration :contentReference[oaicite:8]{index=8}

        // ---- By-category: Applications ----
        if let dict = valueIfResponds(obj, "applicationUsageByCategory") as? NSDictionary { // :contentReference[oaicite:9]{index=9}
            var apps: [[String: Any]] = []
            for (key, value) in dict {
                let category = categoryName(key)
                guard let arr = value as? [NSObject] else { continue }
                for app in arr {
                    var entry: [String: Any] = ["category": category]
                    if let b = valueIfResponds(app, "bundleIdentifier") as? String {
                        entry["bundle_id"] = b
                    }
                    if let rep = valueIfResponds(app, "reportApplicationIdentifier") as? String {
                        entry["report_app_id"] = rep
                    }
                    if let u = seconds(app, key: "totalUsageTime") {
                        entry["usage_s"] = u
                    }
                    if entry.count > 1 { apps.append(entry) }
                }
            }
            if !apps.isEmpty { rec["applications"] = apps }
        }

        // ---- By-category: Web ----
        if let dict = valueIfResponds(obj, "webUsageByCategory") as? NSDictionary { // :contentReference[oaicite:10]{index=10}
            var web: [[String: Any]] = []
            for (key, value) in dict {
                let category = categoryName(key)
                guard let arr = value as? [NSObject] else { continue }
                for w in arr {
                    var entry: [String: Any] = ["category": category]
                    // domain property name is not critical; try common candidates safely
                    let domainKeys = ["domain", "host", "domainName", "site"]
                    for k in domainKeys {
                        if let s = valueIfResponds(w, k) as? String { entry["domain"] = s; break }
                    }
                    if let u = seconds(w, key: "totalUsageTime") { // documented on WebUsage
                        entry["usage_s"] = u                                                              // :contentReference[oaicite:11]{index=11}
                    }
                    if entry.count > 1 { web.append(entry) }
                }
            }
            if !web.isEmpty { rec["web"] = web }
        }

        // ---- By-category: Notifications ----
        if let dict = valueIfResponds(obj, "notificationUsageByCategory") as? NSDictionary { // :contentReference[oaicite:12]{index=12}
            var notifs: [[String: Any]] = []
            for (key, value) in dict {
                let category = categoryName(key)
                guard let arr = value as? [NSObject] else { continue }
                for n in arr {
                    var entry: [String: Any] = ["category": category]
                    // event enum → string. FUAM-3945 fidelity audit, X5: production stores a
                    // number-in-a-string ("0", "11"); `event` is kept verbatim and `event_name`
                    // is the additive symbolic companion.
                    if let ev = valueIfResponds(n, "event") {
                        entry["event"] = String(describing: ev)
                        if let raw = (ev as? NSNumber)?.intValue,
                           let name = notificationEventName(rawValue: raw) {
                            entry["event_name"] = name
                        }
                    }
                    // try both "count" and "totalCount" defensively
                    if let c = (valueIfResponds(n, "count") as? NSNumber)?.intValue {
                        entry["count"] = c
                    } else if let c = (valueIfResponds(n, "totalCount") as? NSNumber)?.intValue {
                        entry["count"] = c
                    }
                    if entry.count > 1 { notifs.append(entry) }
                }
            }
            if !notifs.isEmpty { rec["notifications"] = notifs }
        }

        return rec
    }
}
