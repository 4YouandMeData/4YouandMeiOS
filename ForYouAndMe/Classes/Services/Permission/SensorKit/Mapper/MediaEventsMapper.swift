//
//  MediaEventsMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 09/10/25.
//

import Foundation
import SensorKit

@inline(__always)
private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

// MARK: - Mapper

/// Maps SensorKit `SRMediaEvent` samples into JSON-ready dictionaries.
/// Availability: iOS 16.4+
/// NOTE: Authorization and `startRecording()` are handled elsewhere.
@available(iOS 16.4, *)
final class MediaEventsMapper: NSObject, SensorSampleMapper {

    var sensor: SRSensor { .mediaEvents }

    private let reader = SRSensorReader(sensor: .mediaEvents)
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
                return "SensorKit not authorized for mediaEvents. Status: \(status)."
            }
        }
    }

    // MARK: - SensorSampleMapper

    /// Fetch [from, to) honoring 24h embargo and map SRMediaEvent records.
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

        // If OS < 16.4, this sensor isn't available → return empty
        guard #available(iOS 16.4, *) else {
            completion(.success([]))
            return
        }

        // Enforce embargo: do not read within last 24h
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

@available(iOS 16.4, *)
extension MediaEventsMapper: SRSensorReaderDelegate {

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        didFetchResult result: SRFetchResult<AnyObject>
    ) -> Bool {
        // SRFetchResult.timestamp → when the framework recorded this batch
        let recordedAtISO: String = {
            let iso = ISO8601DateFormatter()
            return iso.string(from: dateFromSRAbsoluteTime(result.timestamp))
        }()

        // Sample may be a fast-enumerable list (e.g., CMSensorDataList-like) or a single object.
        if let enumerable = result.sample as? NSFastEnumeration {
            for element in FastEnumerationSequence(base: enumerable) {
                guard let obj = element as? NSObject,
                      let rec = Self.mapMediaEvent(obj, recordedAtISO: recordedAtISO) else { continue }
                collected.append(rec)
            }
        } else if let obj = result.sample as? NSObject,
                  let rec = Self.mapMediaEvent(obj, recordedAtISO: recordedAtISO) {
            collected.append(rec)
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

@available(iOS 16.4, *)
private extension MediaEventsMapper {

    // Safe KVC helpers
    static func valueIfResponds(_ obj: NSObject, _ key: String) -> Any? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return nil }
        return obj.value(forKey: key)
    }

    static func string(_ obj: NSObject, key: String) -> String? {
        valueIfResponds(obj, key) as? String
    }

    static func enumString(_ any: Any?) -> String? {
        guard let any else { return nil }
        // Try rawValue first, fallback to description
        if let o = any as? NSObject,
           let raw = valueIfResponds(o, "rawValue") as? String {
            return raw
        }
        return String(describing: any)
    }

    static func isMediaEvent(_ obj: NSObject) -> Bool {
        let name = NSStringFromClass(type(of: obj))
        return name.contains("SRMediaEvent") || name.contains("MediaEvent")
    }

    /// Map SRMediaEvent → JSON using documented keys: `eventType`, `mediaIdentifier`.
    static func mapMediaEvent(_ obj: NSObject, recordedAtISO: String) -> [String: Any]? {
        guard isMediaEvent(obj) else { return nil }

        var rec: [String: Any] = [
            "recorded_at": recordedAtISO,
            "device_kind": "iphone"
        ]

        // eventType (enum SRMediaEventType → string)
        if let et = enumString(valueIfResponds(obj, "eventType")) {
            rec["event_type"] = et
        }

        // mediaIdentifier (string)
        if let mid = string(obj, key: "mediaIdentifier") {
            rec["media_identifier"] = mid
        }

        // If nothing useful mapped, drop the record
        return rec.count > 2 ? rec : nil
    }
}
