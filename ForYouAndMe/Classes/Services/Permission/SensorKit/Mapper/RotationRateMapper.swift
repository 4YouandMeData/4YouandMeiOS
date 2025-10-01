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

/// Maps SensorKit rotation-rate (gyroscope) samples into JSON-ready records.
final class RotationRateMapper: NSObject, SensorSampleMapper {

    // This mapper handles the gyroscope stream
    var sensor: SRSensor { .rotationRate }

    private let reader = SRSensorReader(sensor: .rotationRate)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "RotationRateMapper: concurrent fetch not supported")

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
        reader.fetch(req) // delegate-based
    }
}

// MARK: - SRSensorReaderDelegate
extension RotationRateMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        // Typical containers: CMSensorDataList or single sample object
        if let list = result.sample as? CMSensorDataList {
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapRotationSample(obj) {
                    collected.append(rec)
                }
            }
        } else if let obj = result.sample as? NSObject {
            if let rec = Self.mapRotationSample(obj) {
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

    /// Try to extract x/y/z (rad/s) + timestamp from a gyroscope sample via KVC.
    /// We keep it robust across SDK versions by checking multiple key names.
    private static func mapRotationSample(_ obj: NSObject) -> [String: Any]? {
        // Timestamp: prefer 'startDate' then 'timestamp'
        let ts: Date = (obj.value(forKey: "startDate") as? Date)
                    ?? (obj.value(forKey: "timestamp") as? Date)
                    ?? Date.distantPast

        // Rotation rate keys:
        // - Many streams expose plain "x","y","z"
        // - Some expose "rotationRateX/Y/Z"
        // - Some put a nested object "rotationRate" with x/y/z inside
        let x = (obj.value(forKey: "x") as? Double)
             ?? (obj.value(forKey: "rotationRateX") as? Double)
             ?? (obj.value(forKeyPath: "rotationRate.x") as? Double)

        let y = (obj.value(forKey: "y") as? Double)
             ?? (obj.value(forKey: "rotationRateY") as? Double)
             ?? (obj.value(forKeyPath: "rotationRate.y") as? Double)

        let z = (obj.value(forKey: "z") as? Double)
             ?? (obj.value(forKey: "rotationRateZ") as? Double)
             ?? (obj.value(forKeyPath: "rotationRate.z") as? Double)

        guard let gx = x, let gy = y, let gz = z else { return nil }

        return [
            "t": ISO8601Strategy.encode(ts),
            "x": gx, "y": gy, "z": gz,
            "unit": "rad_per_s",
            "device_kind": "iphone"
        ]
    }
}
