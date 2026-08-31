//
//  AmbientLightMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//
// Maps SensorKit ambient light samples to network-ready records.

import Foundation
import SensorKit

/// `SRFetchResult.timestamp` is an `SRAbsoluteTime` (seconds since the 2001 reference date).
private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

final class AmbientLightMapper: NSObject, SensorSampleMapper {

    // Handle SensorKit ambient light stream
    var sensor: SRSensor { .ambientLightSensor }

    private let reader = SRSensorReader(sensor: .ambientLightSensor)
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
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {

        // FUAM-3945 (review C1): fail soft, exactly like the other mappers. The manager's
        // in-flight chain guard is the real protection against a second sync cycle
        // re-entering a mid-fetch mapper; this is defence in depth, and a crash is never
        // the right answer to it in a participant's hands.
        guard self.pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // F10 (review round 1; wording corrected round 3): the best clock available — an
        // improvement, not immunity: a rollback lowers BOTH operands until the next API
        // response re-records the ServerClock offset.
        let safeTo = min(to, max(Date(), ServerClock.now()).addingTimeInterval(-Self.holdingPeriod))
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        let req = SRFetchRequest()
        // FUAM-3945: iPhone or paired Watch — the manager walks one device at a time.
        req.device = device.fetchTarget
        req.from = SRAbsoluteTime.fromCFAbsoluteTime(_cf: from.timeIntervalSinceReferenceDate)
        req.to   = SRAbsoluteTime.fromCFAbsoluteTime(_cf: safeTo.timeIntervalSinceReferenceDate)

        self.collected.removeAll(keepingCapacity: true)
        self.pendingCompletion = completion
        self.reader.delegate = self
        self.reader.fetch(req)
    }
}

extension AmbientLightMapper: SRSensorReaderDelegate {

    // EN: Called for each fetched chunk. For ambient light, SensorKit provides one sample object per result.
    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        // FUAM-4013: `recorded_at` is `SRFetchResult.timestamp` — WHEN SensorKit wrote the
        // record. The backend's semantic anchor (`ClientPush::SemanticAnchor`) reads it as
        // `min(records[].recorded_at)`; without it the anchor silently falls back to upload
        // time and re-uploads scatter into new rows instead of de-duplicating. Same
        // fractional-seconds ISO8601 encoding as the `t` key next to it.
        let recordedAtISO = ISO8601Strategy.encode(dateFromSRAbsoluteTime(result.timestamp))

        // We don't rely on concrete class names; use KVC to extract known fields.
        guard let sampleObj = result.sample as? NSObject else { return true }

        if let record = Self.mapAmbientLight(sampleObj, recordedAtISO: recordedAtISO) {
            self.collected.append(record)
        }

        return true // continue fetching
    }

    /// Extract illuminance (and optional colour temperature) with KVC. Internal (not private)
    /// so the record shape can be unit-tested without an `SRFetchResult`, which cannot be
    /// constructed outside SensorKit.
    static func mapAmbientLight(_ sampleObj: NSObject, recordedAtISO: String) -> [String: Any]? {
        // Timestamp: try 'startDate' first, otherwise 'timestamp' fallback
        let ts = Self.sampleDate(sampleObj, keys: ["startDate", "timestamp"])

        // Illuminance in lux: try common keys
        let luxKeys = ["lux", "illuminance", "sphericalLux", "ambientLux"]
        let lux: Double? = luxKeys.lazy.compactMap { Self.lux(sampleObj, $0) }.first

        // Correlated Color Temperature (Kelvin): optional
        let cctKeys = ["colorTemperature", "cct", "correlatedColorTemperature", "cctK"]
        let cct: Double? = cctKeys.lazy.compactMap { (Self.valueIfResponds(sampleObj, $0) as? NSNumber)?.doubleValue }.first

        // Build record only if we found at least the illuminance
        guard let lux = lux else { return nil }
        var record: [String: Any] = [
            "t": ISO8601Strategy.encode(ts),
            "recorded_at": recordedAtISO,
            "lux": lux,
            "unit": "lux"
        ]
        if let cct = cct {
            record["cct"] = cct
            record["cct_unit"] = "K"
        }

        // FUAM-3945 fidelity audit, X4: documented fields the mapper never read. Inert today
        // (the sensor is unentitled for the current studies) but the mapper should be complete.
        // `placement` is a plain NSInteger property — KVC-reachable — emitted as its symbolic
        // name (a NEW key follows the X5 rule directly).
        if let placementRaw = (Self.valueIfResponds(sampleObj, "placement") as? NSNumber)?.intValue {
            record["placement"] = Self.placementName(rawValue: placementRaw)
        }
        // `chromaticity` is a C struct property (Float32 x/y) — not extractable through KVC —
        // so it needs the typed class, which unit-test stand-ins cannot be. The header states
        // both components are zero on unsupporting devices; an all-zero pair is "not measured",
        // not a measurement, and is omitted.
        if let sample = sampleObj as? SRAmbientLightSample {
            let chromaticity = sample.chromaticity
            if chromaticity.x != 0 || chromaticity.y != 0 {
                record["chromaticity"] = ["x": Double(chromaticity.x), "y": Double(chromaticity.y)]
            }
        }
        return record
    }

    /// FUAM-3945 fidelity audit, X4/X5: symbolic name for `SRAmbientLightSample.SensorPlacement`.
    /// Compile-checked against the SDK enum; raw values the SDK does not know yet are still
    /// carried, as "unknown_<raw>".
    static func placementName(rawValue: Int) -> String {
        guard let placement = SRAmbientLightSample.SensorPlacement(rawValue: rawValue) else {
            return "unknown_\(rawValue)"
        }
        switch placement {
        case .unknown: return "unknown"
        case .frontTop: return "front_top"
        case .frontBottom: return "front_bottom"
        case .frontRight: return "front_right"
        case .frontLeft: return "front_left"
        case .frontTopRight: return "front_top_right"
        case .frontTopLeft: return "front_top_left"
        case .frontBottomRight: return "front_bottom_right"
        case .frontBottomLeft: return "front_bottom_left"
        @unknown default: return "unknown_\(rawValue)"
        }
    }

    /// `SRAmbientLightSample.lux` is a `Measurement<UnitIlluminance>`, not a `Double`: read it as
    /// one first (converting to lux) and fall back to a plain number for any other shape.
    private static func lux(_ obj: NSObject, _ key: String) -> Double? {
        let value = Self.valueIfResponds(obj, key)
        if let measurement = value as? Measurement<UnitIlluminance> {
            return measurement.converted(to: .lux).value
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

    func sensorReader(_ reader: SRSensorReader, didCompleteFetch fetchRequest: SRFetchRequest) {
        guard let completion = self.pendingCompletion else { return }
        let out = self.collected
        self.pendingCompletion = nil
        self.collected.removeAll(keepingCapacity: false)
        completion(.success(out))
    }

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      failedWithError error: any Error) {
        guard let completion = self.pendingCompletion else { return }
        self.pendingCompletion = nil
        self.collected.removeAll(keepingCapacity: false)
        completion(.failure(error))
    }
}
