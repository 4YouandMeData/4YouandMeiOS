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

/// `SRFetchResult.timestamp` is an `SRAbsoluteTime` (seconds since the 2001 reference date).
private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

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

    private enum MapperError: LocalizedError {
        case busy

        var errorDescription: String? {
            return "Mapper is busy: a fetch is already in flight."
        }
    }

    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String : Any]], Error>) -> Void) {

        // FUAM-3945 (review C1): fail soft, exactly like the other mappers. The manager's
        // in-flight chain guard is the real protection against a second sync cycle
        // re-entering a mid-fetch mapper; this is defence in depth, and a crash is never
        // the right answer to it in a participant's hands.
        guard self.pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Respect 24h holding period
        // F10 (review round 1): never the raw device clock — a rollback between plan time and
        // fetch time must not silently truncate the planned span.
        let safeTo = min(to, max(Date(), ServerClock.now()).addingTimeInterval(-Self.holdingPeriod))
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        // Build request converting Date -> SRAbsoluteTime (CFAbsoluteTime since 2001-01-01)
        let req = SRFetchRequest()
        // FUAM-3945: iPhone or paired Watch — the manager walks one device at a time.
        req.device = device.fetchTarget
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

        // FUAM-4013: `recorded_at` is `SRFetchResult.timestamp` — WHEN SensorKit wrote the
        // record. The backend's semantic anchor (`ClientPush::SemanticAnchor`) reads it as
        // `min(records[].recorded_at)`; without it the anchor silently falls back to upload
        // time and re-uploads scatter into new rows instead of de-duplicating. Same
        // fractional-seconds ISO8601 encoding as the `t` key next to it.
        let recordedAtISO = ISO8601Strategy.encode(dateFromSRAbsoluteTime(result.timestamp))

        if let list = result.sample as? CMSensorDataList {
            // Iterate via NSFastEnumeration wrapper you already have (do not add Sequence conformance)
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapAmbientPressure(obj, recordedAtISO: recordedAtISO) {
                    collected.append(rec)
                }
            }
        } else if let obj = result.sample as? NSObject {
            if let rec = Self.mapAmbientPressure(obj, recordedAtISO: recordedAtISO) {
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
    /// Internal (not private) so the record shape can be unit-tested without an
    /// `SRFetchResult`, which cannot be constructed outside SensorKit.
    static func mapAmbientPressure(_ obj: NSObject, recordedAtISO: String) -> [String: Any]? {
        let ts = Self.sampleDate(obj, keys: ["timestamp", "startDate", "date"])

        // Pressure in kPa (common KVC names)
        let pressure: Double? =
              Self.kilopascals(obj, "pressure")
           ?? Self.kilopascals(obj, "pressureKPa")
           ?? Self.kilopascals(obj, "ambientPressure")
           ?? (Self.valuePathIfResponds(obj, "pressure.value") as? NSNumber)?.doubleValue

        // Optional: relative altitude (meters) and sea-level pressure (kPa)
        let relAlt: Double? =
              (Self.valueIfResponds(obj, "relativeAltitude") as? NSNumber)?.doubleValue
           ?? (Self.valueIfResponds(obj, "relativeAltitudeMeters") as? NSNumber)?.doubleValue
           ?? (Self.valuePathIfResponds(obj, "relativeElevation") as? NSNumber)?.doubleValue

        let slp: Double? =
              Self.kilopascals(obj, "seaLevelPressure")
           ?? Self.kilopascals(obj, "seaLevelPressureKPa")

        // If no pressure at all, skip
        guard let p = pressure else { return nil }

        var rec: [String: Any] = [
            "t": ISO8601Strategy.encode(ts),
            "recorded_at": recordedAtISO,
            "pressure_kpa": p
        ]
        if let ra = relAlt { rec["relative_altitude_m"] = ra }
        if let s  = slp    { rec["sea_level_pressure_kpa"] = s }

        return rec
    }

    /// `SRAmbientPressureSample.pressure` is a `Measurement<UnitPressure>`, not a `Double`: read
    /// it as one first (converting to kPa, the unit this record documents) and fall back to a
    /// plain number for any other shape.
    private static func kilopascals(_ obj: NSObject, _ key: String) -> Double? {
        let value = Self.valueIfResponds(obj, key)
        if let measurement = value as? Measurement<UnitPressure> {
            return measurement.converted(to: .kilopascals).value
        }
        return (value as? NSNumber)?.doubleValue
    }

    // MARK: - Safe KVC
    //
    // FUAM-3945 round 7: these mappers PROBE speculative key names, and a bare
    // `value(forKey:)` on an object that does not implement the key raises
    // `NSUnknownKeyException` — an Objective-C exception, uncatchable from Swift, i.e. a crash.
    // The mappers that were already enabled all guard with `responds(to:)`
    // (`DeviceUsageReportMapper.valueIfResponds` and friends); these three did not, which is
    // why enabling them without this would have crashed on the first fetch.

    static func valueIfResponds(_ obj: NSObject, _ key: String) -> Any? {
        guard obj.responds(to: NSSelectorFromString(key)) else { return nil }
        return obj.value(forKey: key)
    }

    /// Safe `value(forKeyPath:)`: every component is probed before it is followed.
    static func valuePathIfResponds(_ obj: NSObject, _ keyPath: String) -> Any? {
        var current: Any? = obj
        for component in keyPath.split(separator: ".").map(String.init) {
            guard let object = current as? NSObject,
                  let next = Self.valueIfResponds(object, component) else { return nil }
            current = next
        }
        return current
    }

    /// The measurement instant of a sample. SensorKit exposes it either as a `Date` or as an
    /// `SRAbsoluteTime` (a `double` of CFAbsoluteTime seconds, which KVC hands back as an
    /// `NSNumber`). A numeric value landing in the future is not a CFAbsoluteTime we understand,
    /// so it is refused rather than guessed at — `distantPast` fails the consent gate, which is
    /// the safe direction.
    static func sampleDate(_ obj: NSObject, keys: [String]) -> Date {
        for key in keys {
            let value = Self.valueIfResponds(obj, key)
            if let date = value as? Date { return date }
            if let number = value as? NSNumber {
                let candidate = Date(timeIntervalSinceReferenceDate: number.doubleValue)
                if candidate.timeIntervalSinceNow < 24 * 60 * 60 { return candidate }
            }
        }
        return Date.distantPast
    }
}
