//
//  MessagesUsageReportMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

//
//  MessagesUsageReportMapper.swift
//

import Foundation
import SensorKit


/// Convert SRAbsoluteTime back to Date using CFAbsoluteTime epoch (2001-01-01).
private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

// MARK: - Mapper

/// Maps SensorKit `SRMessagesUsageReport` into JSON-ready dictionaries.
/// NOTE: Authorization and `startRecording()` are handled elsewhere.
final class MessagesUsageReportMapper: NSObject, SensorSampleMapper {

    // Expose the sensor this mapper handles
    var sensor: SRSensor { .messagesUsageReport }

    private let reader = SRSensorReader(sensor: .messagesUsageReport)
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

    /// Fetch the given [from, to) window, honoring the 24h embargo and mapping SRMessagesUsageReport.
    func fetchAndMap(
        from: Date,
        to: Date,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        // Avoid crashing on concurrent calls
        guard pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Enforce embargo: do not read within last 24h
        let embargoCutoff = Date().addingTimeInterval(-Self.holdingPeriod)
        let safeTo = min(to, embargoCutoff)
        guard from < safeTo else {
            completion(.success([]))
            return
        }

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

extension MessagesUsageReportMapper: SRSensorReaderDelegate {

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        didFetchResult result: SRFetchResult<AnyObject>
    ) -> Bool {
        // Attach SRFetchResult.timestamp as recorded_at
        let recordedAt = dateFromSRAbsoluteTime(result.timestamp)

        // Usage reports arrive as single aggregated objects (no CMSensorDataList).
        if let report = result.sample as? NSObject,
           let record = Self.mapMessagesUsage(report, recordedAt: recordedAt) {
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

private extension MessagesUsageReportMapper {

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

    static func seconds(_ obj: NSObject, key: String) -> Double? {
        if let m = valueIfResponds(obj, key) as? Measurement<UnitDuration> {
            return m.converted(to: .seconds).value
        }
        if let n = valueIfResponds(obj, key) as? NSNumber {
            return n.doubleValue
        }
        return nil
    }

    /// Map SRMessagesUsageReport -> flat JSON using documented keys.
    static func mapMessagesUsage(
        _ obj: NSObject,
        recordedAt: Date?
    ) -> [String: Any]? {
        // Guard the expected class name to avoid KVC crashes on other sample types.
        let typeName = NSStringFromClass(type(of: obj))
        guard typeName.contains("MessagesUsageReport") else { return nil }

        let iso = ISO8601DateFormatter()
        var rec: [String: Any] = [:]

        // Timestamp when the framework recorded the sample (SRFetchResult.timestamp)
        if let ts = recordedAt { rec["recorded_at"] = iso.string(from: ts) }

        // Period bounds if present on this report type
        if let start = kvcDate(obj, key: "startDate") { rec["start"] = iso.string(from: start) }
        if let end = kvcDate(obj, key: "endDate") { rec["end"] = iso.string(from: end) }

        // Duration that the report spans
        if let dur = seconds(obj, key: "duration") { rec["duration_s"] = dur } // :contentReference[oaicite:1]{index=1}

        // Documented counters
        if let v = intValue(obj, key: "totalIncomingMessages") { rec["total_incoming_messages"] = v } // :contentReference[oaicite:2]{index=2}
        if let v = intValue(obj, key: "totalOutgoingMessages") { rec["total_outgoing_messages"] = v } // :contentReference[oaicite:3]{index=3}
        if let v = intValue(obj, key: "totalUniqueContacts")  { rec["total_unique_contacts"]  = v } // :contentReference[oaicite:4]{index=4}

        // Explicit device tag
        rec["device_kind"] = "iphone"

        return rec
    }
}
