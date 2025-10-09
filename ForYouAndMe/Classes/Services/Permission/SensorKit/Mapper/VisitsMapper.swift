//
//  VisitsMapper.swift
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

/// Maps SensorKit `SRVisit` samples into JSON-ready dictionaries (documented keys only).
/// NOTE: Authorization and `startRecording()` are handled elsewhere.
final class VisitsMapper: NSObject, SensorSampleMapper {

    var sensor: SRSensor { .visits }

    private let reader = SRSensorReader(sensor: .visits)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected = [[String: Any]]()

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    // Errors
    private enum MapperError: LocalizedError {
        case busy
        case notAuthorized(status: SRAuthorizationStatus)

        var errorDescription: String? {
            switch self {
            case .busy:
                return "Mapper is busy: a fetch is already in flight."
            case let .notAuthorized(status):
                return "SensorKit not authorized for visits. Status: \(status)."
            }
        }
    }

    // MARK: - SensorSampleMapper

    func fetchAndMap(
        from: Date,
        to: Date,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        // Prevent concurrent fetches
        guard pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Enforce 24h embargo
        let embargoCutoff = Date().addingTimeInterval(-Self.holdingPeriod)
        let safeTo = min(to, embargoCutoff)
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        // Build request
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

extension VisitsMapper: SRSensorReaderDelegate {

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        didFetchResult result: SRFetchResult<AnyObject>
    ) -> Bool {
        // Attach SRFetchResult.timestamp as recorded_at
        let recordedAt = dateFromSRAbsoluteTime(result.timestamp)

        // SRVisit arrives as single objects (no CMSensorDataList expected)
        if let visit = result.sample as? NSObject,
           let record = Self.mapVisit(visit, recordedAt: recordedAt) {
            collected.append(record)
        }
        return true // continue fetching
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

    private func finish(_ result: Result<[[String: Any]], Error>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        reader.delegate = nil
        completion?(result)
    }
}

// MARK: - Mapping (documented keys only, safe KVC)

private extension VisitsMapper {

    // Safe KVC helpers
    static func valueIfResponds(_ obj: NSObject, _ key: String) -> Any? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return nil }
        return obj.value(forKey: key)
    }

    static func string(_ obj: NSObject, key: String) -> String? {
        valueIfResponds(obj, key) as? String
    }

    static func uuidString(_ obj: NSObject, key: String) -> String? {
        if let u = valueIfResponds(obj, key) as? UUID { return u.uuidString }
        return string(obj, key: key) // fallback if bridged as string
    }

    static func seconds(from dateInterval: DateInterval?) -> Double? {
        guard let di = dateInterval else { return nil }
        return di.duration
    }

    static func kvcDateInterval(_ obj: NSObject, key: String) -> DateInterval? {
        valueIfResponds(obj, key) as? DateInterval
    }

    static func double(_ obj: NSObject, key: String) -> Double? {
        (valueIfResponds(obj, key) as? NSNumber)?.doubleValue
    }

    static func enumString(_ any: Any?) -> String? {
        guard let any else { return nil }
        // Prefer rawValue (String) when exposed; else type description
        if let o = any as? NSObject,
           let raw = valueIfResponds(o, "rawValue") as? String {
            return raw
        }
        return String(describing: any)
    }

    static func isSRVisit(_ obj: NSObject) -> Bool {
        NSStringFromClass(type(of: obj)).contains("SRVisit")
    }

    /// Map SRVisit → JSON (identifier, arrival/departure intervals, distanceFromHome, locationCategory, recorded_at)
    static func mapVisit(_ obj: NSObject, recordedAt: Date?) -> [String: Any]? {
        guard isSRVisit(obj) else { return nil }

        let iso = ISO8601DateFormatter()
        var rec: [String: Any] = ["device_kind": "iphone"]

        // When SensorKit recorded this sample
        if let ts = recordedAt { rec["recorded_at"] = iso.string(from: ts) }

        // Unique location identifier (UUID)
        if let id = uuidString(obj, key: "identifier") {
            rec["location_id"] = id // maps to “unique geographic location” per docs
        }

        // Arrival and departure windows (DateInterval → {start,end} ISO-8601)
        if let arr = kvcDateInterval(obj, key: "arrivalDateInterval") {
            rec["arrival"] = [
                "start": iso.string(from: arr.start),
                "end": iso.string(from: arr.end)
            ]
        }
        if let dep = kvcDateInterval(obj, key: "departureDateInterval") {
            rec["departure"] = [
                "start": iso.string(from: dep.start),
                "end": iso.string(from: dep.end)
            ]
        }

        // Distance from home (meters)
        if let d = double(obj, key: "distanceFromHome") {
            rec["distance_from_home_m"] = d
        }

        // Location category enum → readable string (e.g., home/work/school/…)
        if let cat = enumString(valueIfResponds(obj, "locationCategory")) {
            rec["location_category"] = cat
        }

        // NB: SRVisit does NOT expose raw coordinates (privacy); we do not emit lat/lon.

        // If nothing was mapped (extreme edge), return nil to skip
        return rec.count > 1 ? rec : nil
    }
}
