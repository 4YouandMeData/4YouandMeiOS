//
//  RotationRateMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

//
//  RotationRateMapper.swift
//

import Foundation
import SensorKit
import CoreMotion

/// `SRFetchResult.timestamp` is an `SRAbsoluteTime` (seconds since the 2001 reference date).
private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

/// Maps SensorKit rotation-rate (gyroscope) samples into JSON-ready records.
final class RotationRateMapper: NSObject, SensorSampleMapper {

    // This mapper handles the gyroscope stream
    var sensor: SRSensor { .rotationRate }

    private let reader = SRSensorReader(sensor: .rotationRate)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []
    private var fetchedResults = 0

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

        // Fail soft like every other mapper: a precondition here crashes the app in Release on a
        // concurrent cycle, and "a fetch is already running" is never the right answer to crash on
        // in a participant's hands. The in-flight chain guard is the primary protection.
        guard self.pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Respect 24h holding period
        // F10 (review round 1; wording corrected round 3): the best clock available — an
        // improvement, not immunity: a rollback lowers BOTH operands until the next API
        // response re-records the ServerClock offset.
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
        fetchedResults = 0
        pendingCompletion = completion
        reader.delegate = self
        reader.fetch(req) // delegate-based
    }
}

// MARK: - SRSensorReaderDelegate
extension RotationRateMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        // FUAM-4013: `recorded_at` is `SRFetchResult.timestamp` — WHEN SensorKit wrote the
        // record. The backend's semantic anchor (`ClientPush::SemanticAnchor`) reads it as
        // `min(records[].recorded_at)`; without it the anchor silently falls back to upload
        // time and re-uploads scatter into new rows instead of de-duplicating. Same
        // fractional-seconds ISO8601 encoding as the `t` key next to it.
        let recordedAtISO = ISO8601Strategy.encode(dateFromSRAbsoluteTime(result.timestamp))

        fetchedResults += 1

        // Typical containers: CMSensorDataList or single sample object
        var records: [[String: Any]] = []
        if let list = result.sample as? CMSensorDataList {
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapRotationSample(obj, recordedAtISO: recordedAtISO) {
                    records.append(rec)
                }
            }
        } else if let obj = result.sample as? NSObject {
            if let rec = Self.mapRotationSample(obj, recordedAtISO: recordedAtISO) {
                records.append(rec)
            }
        }
        // FUAM-3945: ledger identity — the raw monotonic timestamp, never its wall
        // projection (see SensorRecordIdentity). The raw value ships only when it identifies a
        // single record; list siblings share it.
        collected.append(contentsOf: SensorRecordIdentity.stampedResult(records,
                                                                         raw: result.timestamp,
                                                                         replacing: ["recorded_at"]))
        return true // continue fetching
    }

    func sensorReader(_ reader: SRSensorReader, didCompleteFetch fetchRequest: SRFetchRequest) {
        guard let completion = pendingCompletion else { return }
        let result = self.classifyFetchOutcome(collected: collected, fetchedResults: fetchedResults)
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        completion(result)
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

    /// Try to extract x/y/z (rad/s) + timestamp from a gyroscope sample via KVC.
    /// We keep it robust across SDK versions by checking multiple key names.
    /// Internal (not private) so the record shape can be unit-tested without an
    /// `SRFetchResult`, which cannot be constructed outside SensorKit.
    static func mapRotationSample(_ obj: NSObject, recordedAtISO: String) -> [String: Any]? {
        // Timestamp: prefer 'startDate' then 'timestamp'
        let ts = Self.sampleDate(obj, keys: ["startDate", "timestamp"])

        // Rotation rate keys:
        // - Many streams expose plain "x","y","z"
        // - Some expose "rotationRateX/Y/Z"
        // - Some put a nested object "rotationRate" with x/y/z inside
        let x = Self.axis(obj, "x", "rotationRateX", "rotationRate.x")
        let y = Self.axis(obj, "y", "rotationRateY", "rotationRate.y")
        let z = Self.axis(obj, "z", "rotationRateZ", "rotationRate.z")

        guard let gx = x, let gy = y, let gz = z else { return nil }

        return [
            "t": ISO8601Strategy.encode(ts),
            "recorded_at": recordedAtISO,
            "x": gx, "y": gy, "z": gz,
            "unit": "rad_per_s"
        ]
    }

    /// One rotation axis, tried as a flat key, a prefixed key, then a nested key path.
    private static func axis(_ obj: NSObject, _ key: String, _ prefixed: String, _ path: String) -> Double? {
        return (Self.valueIfResponds(obj, key) as? NSNumber)?.doubleValue
            ?? (Self.valueIfResponds(obj, prefixed) as? NSNumber)?.doubleValue
            ?? (Self.valuePathIfResponds(obj, path) as? NSNumber)?.doubleValue
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
