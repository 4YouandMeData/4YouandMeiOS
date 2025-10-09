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
/// NOTE: authorization e startRecording() sono gestiti altrove.
final class DeviceUsageReportMapper: NSObject, SensorSampleMapper {

    // SRSensor di competenza
    var sensor: SRSensor { .deviceUsageReport }

    // Reader dedicato
    private let reader = SRSensorReader(sensor: .deviceUsageReport)

    // Stato richiesta corrente (evita concorrenza)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected = [[String: Any]]()

    // Apple impone un embargo di ~24h sui dati
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    // Errori mapper
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

    /// Esegue fetch [from, to) rispettando l’embargo 24h e mappa SRDeviceUsageReport.
    func fetchAndMap(
        from: Date,
        to: Date,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        // Evita crash su richieste concorrenti
        guard pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Applica il cutoff: non leggere l’ultima 24h
        let embargoCutoff = Date().addingTimeInterval(-Self.holdingPeriod)
        let safeTo = min(to, embargoCutoff)
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        // Costruzione SRFetchRequest
        let req = SRFetchRequest()
        req.device = SRDevice.current
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

        // Report aggregato (non CMSensorDataList)
        if let obj = result.sample as? NSObject,
           let rec = Self.mapDeviceUsage(obj, recordedAt: recordedAt) {
            collected.append(rec)
        }
        return true // continua il fetch
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

private extension DeviceUsageReportMapper {

    // Safe KVC: chiama value(forKey:) solo se il selettore esiste
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
        var rec: [String: Any] = ["device_kind": "iphone"]

        // Timestamps
        if let ts = recordedAt { rec["recorded_at"] = iso.string(from: ts) }
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
                    // event enum → string
                    if let ev = valueIfResponds(n, "event") {
                        entry["event"] = String(describing: ev)
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
