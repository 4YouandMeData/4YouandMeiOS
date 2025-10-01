//
//  AmbientPressureMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

//
//  AmbientPressureMapper.swift
//

import Foundation
import SensorKit
import CoreMotion

/// Maps SensorKit ambient pressure (barometer / elevation) samples into JSON-ready records.
/// Uses KVC to stay resilient across SDK field/name variations.
final class AmbientPressureMapper: NSObject, SensorSampleMapper {

    // This mapper handles barometric pressure / elevation stream
    var sensor: SRSensor { .ambientPressure }

    private let reader = SRSensorReader(sensor: .ambientPressure)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String : Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "AmbientPressureMapper: concurrent fetch not supported")

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
        reader.fetch(req) // delegate-based API
    }
}

// MARK: - SRSensorReaderDelegate
extension AmbientPressureMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        if let list = result.sample as? CMSensorDataList {
            // Iterate via NSFastEnumeration wrapper you already have (do not add Sequence conformance)
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapAmbientPressure(obj) {
                    collected.append(rec)
                }
            }
        } else if let obj = result.sample as? NSObject {
            if let rec = Self.mapAmbientPressure(obj) {
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

    // MARK: - Mapping

    /// Extract pressure/elevation with KVC; normalize to stable keys.
    /// Expected units:
    /// - pressure_kpa: kiloPascals
    /// - sea_level_pressure_kpa: kiloPascals (if present)
    /// - relative_altitude_m: meters (if present)
    private static func mapAmbientPressure(_ obj: NSObject) -> [String: Any]? {
        let ts: Date = (obj.value(forKey: "timestamp") as? Date)
                    ?? (obj.value(forKey: "startDate") as? Date)
                    ?? (obj.value(forKey: "date") as? Date)
                    ?? Date.distantPast

        // Pressure in kPa (common KVC names)
        let pressure: Double? =
              (obj.value(forKey: "pressure") as? NSNumber)?.doubleValue
           ?? (obj.value(forKey: "pressureKPa") as? NSNumber)?.doubleValue
           ?? (obj.value(forKey: "ambientPressure") as? NSNumber)?.doubleValue
           ?? (obj.value(forKeyPath: "pressure.value") as? NSNumber)?.doubleValue

        // Optional: relative altitude (meters) and sea-level pressure (kPa)
        let relAlt: Double? =
              (obj.value(forKey: "relativeAltitude") as? NSNumber)?.doubleValue
           ?? (obj.value(forKey: "relativeAltitudeMeters") as? NSNumber)?.doubleValue
           ?? (obj.value(forKeyPath: "relativeElevation") as? NSNumber)?.doubleValue

        let slp: Double? =
              (obj.value(forKey: "seaLevelPressure") as? NSNumber)?.doubleValue
           ?? (obj.value(forKey: "seaLevelPressureKPa") as? NSNumber)?.doubleValue

        // If no pressure at all, skip
        guard let p = pressure else { return nil }

        var rec: [String: Any] = [
            "t": ISO8601Strategy.encode(ts),
            "pressure_kpa": p,
            "device_kind": "iphone"
        ]
        if let ra = relAlt { rec["relative_altitude_m"] = ra }
        if let s  = slp    { rec["sea_level_pressure_kpa"] = s }

        return rec
    }
}
