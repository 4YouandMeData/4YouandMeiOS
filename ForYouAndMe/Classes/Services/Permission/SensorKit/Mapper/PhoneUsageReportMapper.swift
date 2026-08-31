//
//  PhoneUsageReportMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//
//
//  PhoneUsageReportMapper.swift
//

import Foundation
import SensorKit

/// Convert SRAbsoluteTime back to Date using CFAbsoluteTime epoch (2001-01-01).
private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

// MARK: - Mapper

/// Maps SensorKit `SRPhoneUsageReport` into JSON-ready dictionaries.
/// NOTE: Authorization and `startRecording()` are handled elsewhere.
final class PhoneUsageReportMapper: NSObject, SensorSampleMapper {

    var sensor: SRSensor { .phoneUsageReport }

    private let reader = SRSensorReader(sensor: .phoneUsageReport)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected = [[String: Any]]()

    // Apple withholds last 24h of SensorKit data (absolute hours)
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    // MARK: - Errors

    private enum MapperError: LocalizedError {
        case busy
        case notAuthorized(sensor: SRSensor, status: SRAuthorizationStatus)

        var errorDescription: String? {
            switch self {
            case .busy:
                return "Mapper is busy: a fetch is already in flight."
            case let .notAuthorized(sensor, status):
                return "SensorKit not authorized for \(sensor). Status: \(status)."
            }
        }
    }

    // MARK: - SensorSampleMapper

    /// Fetch the given [from, to) window, honoring the 24h embargo and mapping SRPhoneUsageReport.
    func fetchAndMap(
        from: Date,
        to: Date,
        device: SensorDevice,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        // Avoid crashing on concurrent calls
        guard pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Enforce embargo: do not read within last 24h
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

extension PhoneUsageReportMapper: SRSensorReaderDelegate {

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        didFetchResult result: SRFetchResult<AnyObject>
    ) -> Bool {
        // Attach SRFetchResult.timestamp as recorded_at
        let recordedAt = dateFromSRAbsoluteTime(result.timestamp)

        // Usage reports are aggregated objects (no CMSensorDataList expected)
        if let report = result.sample as? NSObject,
           let record = Self.mapPhoneUsage(report, recordedAt: recordedAt) {
            collected.append(record)
        }
        return true // continue
    }

    func sensorReader(
        _ reader: SRSensorReader,
        didCompleteFetch fetchRequest: SRFetchRequest
    ) {
        finish(.success(collected))
    }

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        failedWithError error: Error
    ) {
        finish(.failure(error))
    }

    // Centralized cleanup + callback
    private func finish(_ result: Result<[[String: Any]], Error>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        reader.delegate = nil
        completion?(result)
    }
}

// MARK: - Mapping (documented keys only)

// Internal (was private): the per-mapper recorded_at anchor-guard specs exercise the mapping
// seams with KVC stand-ins (FUAM-3945 round 9, F1: a mapper regression dropping recorded_at
// silently degrades the server row anchor to upload time).
extension PhoneUsageReportMapper {

    // --- Safe KVC (only call value(forKey:) if the selector exists) ---
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

    /// Map SRPhoneUsageReport -> flat JSON using documented keys.
    static func mapPhoneUsage(
        _ obj: NSObject,
        recordedAt: Date?
    ) -> [String: Any]? {
        // Guard the expected class name to avoid KVC crashes on other sample types.
        let typeName = NSStringFromClass(type(of: obj))
        guard typeName.contains("PhoneUsageReport") else { return nil }

        let iso = ISO8601DateFormatter()
        var rec: [String: Any] = [:]

        // Timestamp when the framework recorded the sample (SRFetchResult.timestamp).
        // `recorded_at` stays whole-second verbatim (server row anchor, historical shape);
        // `recorded_at_precise` is the additive fractional-seconds companion (FUAM-3945, X6).
        if let ts = recordedAt {
            rec["recorded_at"] = iso.string(from: ts)
            rec["recorded_at_precise"] = ISO8601Strategy.encode(ts)
        }

        // Period bounds if present
        if let start = kvcDate(obj, key: "startDate") { rec["start"] = iso.string(from: start) }
        if let end = kvcDate(obj, key: "endDate") { rec["end"] = iso.string(from: end) }

        // Duration that the report spans (Measurement<UnitDuration>)
        if let dur = seconds(obj, key: "duration") { rec["duration_s"] = dur } // Apple: duration. :contentReference[oaicite:5]{index=5}

        // Documented counters & durations
        if let v = intValue(obj, key: "totalIncomingCalls") { rec["total_incoming_calls"] = v } // :contentReference[oaicite:6]{index=6}
        if let v = intValue(obj, key: "totalOutgoingCalls") { rec["total_outgoing_calls"] = v } // :contentReference[oaicite:7]{index=7}
        if let v = seconds(obj, key: "totalPhoneCallDuration") { rec["total_phone_call_duration_s"] = v } // :contentReference[oaicite:8]{index=8}
        if let v = intValue(obj, key: "totalUniqueContacts") { rec["total_unique_contacts"] = v } // :contentReference[oaicite:9]{index=9}

        return rec
    }
}
