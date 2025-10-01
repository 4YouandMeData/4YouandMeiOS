//
//  VisitsMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit
import CoreMotion

/// Maps SensorKit "visits" into JSON-ready records.
/// We avoid compile-time coupling and use KVC to be resilient to SDK changes.
final class VisitsMapper: NSObject, SensorSampleMapper {

    // This mapper handles the "visits" stream
    var sensor: SRSensor { .visits }

    private let reader = SRSensorReader(sensor: .visits)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last ~24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String : Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "VisitsMapper: concurrent fetch not supported")

        // Respect 24h holding period
        let safeTo = min(to, Date().addingTimeInterval(-Self.holdingPeriod))
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        // Build request converting Date -> SRAbsoluteTime (CFAbsoluteTime since 2001-01-01)
        let req = SRFetchRequest()
        req.device = SRDevice.current
        req.from = SRAbsoluteTime.fromCFAbsoluteTime(_cf: from.timeIntervalSinceReferenceDate)
        req.to   = SRAbsoluteTime.fromCFAbsoluteTime(_cf: safeTo.timeIntervalSinceReferenceDate)

        collected.removeAll(keepingCapacity: true)
        pendingCompletion = completion
        reader.delegate = self
        reader.fetch(req) // delegate-based API (no trailing closure)
    }
}

// MARK: - SRSensorReaderDelegate
extension VisitsMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        if let list = result.sample as? CMSensorDataList {
            // Iterate batched results via NSFastEnumeration wrapper (already defined in the project)
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapVisit(obj) {
                    collected.append(rec)
                }
            }
        } else if let obj = result.sample as? NSObject {
            if let rec = Self.mapVisit(obj) {
                collected.append(rec)
            }
        }
        return true // continue fetching
    }

    func sensorReader(_ reader: SRSensorReader, didCompleteFetch fetchRequest: SRFetchRequest) {
        guard let completion = pendingCompletion else { return }
        let out = collected
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        completion(.success(out))
    }

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      failedWithError error: any Error) {
        guard let completion = pendingCompletion else { return }
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        completion(.failure(error))
    }

    // MARK: - Mapping helpers

    /// KVC-based extraction of a visit sample.
    /// Normalized fields:
    ///  - start, end: ISO8601 strings
    ///  - lat, lon: doubles (if available)
    ///  - accuracy_m: double (if available)
    ///  - confidence: int (if available)
    ///  - device_kind: "iphone"
    private static func mapVisit(_ obj: NSObject) -> [String: Any]? {
        let fmt = ISO8601DateFormatter()

        // Time bounds (best-effort)
        let start: Date = (obj.value(forKey: "arrivalDate") as? Date)
                       ?? (obj.value(forKey: "arrival") as? Date)
                       ?? (obj.value(forKey: "startDate") as? Date)
                       ?? (obj.value(forKey: "start") as? Date)
                       ?? Date.distantPast

        let end: Date? = (obj.value(forKey: "departureDate") as? Date)
                      ?? (obj.value(forKey: "departure") as? Date)
                      ?? (obj.value(forKey: "endDate") as? Date)
                      ?? (obj.value(forKey: "end") as? Date)

        // Location: try multiple shapes (flat keys / nested center/location)
        let lat: Double? =
              (obj.value(forKey: "latitude") as? NSNumber)?.doubleValue
           ?? (obj.value(forKeyPath: "center.latitude") as? NSNumber)?.doubleValue
           ?? (obj.value(forKeyPath: "location.coordinate.latitude") as? NSNumber)?.doubleValue

        let lon: Double? =
              (obj.value(forKey: "longitude") as? NSNumber)?.doubleValue
           ?? (obj.value(forKeyPath: "center.longitude") as? NSNumber)?.doubleValue
           ?? (obj.value(forKeyPath: "location.coordinate.longitude") as? NSNumber)?.doubleValue

        let hAcc: Double? =
              (obj.value(forKey: "horizontalAccuracy") as? NSNumber)?.doubleValue
           ?? (obj.value(forKeyPath: "location.horizontalAccuracy") as? NSNumber)?.doubleValue

        // Confidence/category (optional; names may vary)
        let conf: Int? =
              (obj.value(forKey: "confidence") as? NSNumber)?.intValue
           ?? (obj.value(forKey: "placeConfidence") as? NSNumber)?.intValue

        // Compose output; require at least a start time.
        var rec: [String: Any] = [
            "start": fmt.string(from: start),
            "device_kind": "iphone"
        ]
        if let end = end { rec["end"] = fmt.string(from: end) }
        if let la = lat, let lo = lon { rec["lat"] = la; rec["lon"] = lo }
        if let acc = hAcc { rec["accuracy_m"] = acc }
        if let c = conf { rec["confidence"] = c }

        return rec
    }
}
