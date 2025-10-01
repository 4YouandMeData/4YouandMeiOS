//
//  PedometerMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

//
//  PedometerMapper.swift
//

import Foundation
import SensorKit
import CoreMotion

final class PedometerMapper: NSObject, SensorSampleMapper {

    // This mapper handles SensorKit pedometer stream
    var sensor: SRSensor { .pedometerData }

    private let reader = SRSensorReader(sensor: .pedometerData)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String : Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "PedometerMapper: concurrent fetch not supported")

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
        reader.fetch(req) // <-- delegate-based, no trailing closure
    }
}

// MARK: - SRSensorReaderDelegate
extension PedometerMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {
        // result.sample can be a CMSensorDataList or a single CMPedometerData
        if let list = result.sample as? CMSensorDataList {
            // Iterate NSFastEnumeration via wrapper (no direct Sequence conformance)
            for element in FastEnumerationSequence(base: list) {
                guard let pedo = element as? CMPedometerData else { continue }
                collected.append(Self.mapPedometerSample(pedo))
            }
        } else if let pedo = result.sample as? CMPedometerData {
            collected.append(Self.mapPedometerSample(pedo))
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

    /// Compact JSON for a CMPedometerData sample
    private static func mapPedometerSample(_ d: CMPedometerData) -> [String: Any] {
        // Units (CoreMotion):
        // - numberOfSteps: count
        // - distance: meters (NSNumber?)
        // - currentPace: seconds per meter (NSNumber?)
        // - currentCadence: steps per second (NSNumber?)
        // - averageActivePace: seconds per meter (NSNumber?)
        // - floorsAscended/Descended: count (NSNumber?)
        var rec: [String: Any] = [
            "start_ms": Int(d.startDate.timeIntervalSince1970 * 1000),
            "end_ms":   Int(d.endDate.timeIntervalSince1970 * 1000),
            "steps":    d.numberOfSteps.intValue
        ]
        if let dist = d.distance?.doubleValue { rec["distance_m"] = dist }
        if let pace = d.currentPace?.doubleValue { rec["current_pace_s_per_m"] = pace }
        if let cad  = d.currentCadence?.doubleValue { rec["current_cadence_steps_per_s"] = cad }
        if let avgP = d.averageActivePace?.doubleValue { rec["avg_active_pace_s_per_m"] = avgP }
        if let up   = d.floorsAscended?.intValue { rec["floors_up"] = up }
        if let down = d.floorsDescended?.intValue { rec["floors_down"] = down }
        rec["device_kind"] = "iphone"
        return rec
    }
}
