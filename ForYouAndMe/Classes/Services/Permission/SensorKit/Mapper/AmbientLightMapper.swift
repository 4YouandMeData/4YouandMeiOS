//
//  AmbientLightMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//
// Maps SensorKit ambient light samples to network-ready records.

import Foundation
import SensorKit

final class AmbientLightMapper: NSObject, SensorSampleMapper {

    // Handle SensorKit ambient light stream
    var sensor: SRSensor { .ambientLightSensor }

    private let reader = SRSensorReader(sensor: .ambientLightSensor)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "AmbientLightMapper: concurrent fetch not supported")

        let safeTo = min(to, Date().addingTimeInterval(-Self.holdingPeriod))
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        let req = SRFetchRequest()
        req.device = SRDevice.current
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

        // We don't rely on concrete class names; use KVC to extract known fields.
        guard let sampleObj = result.sample as? NSObject else { return true }

        // Timestamp: try 'startDate' first, otherwise 'timestamp' fallback
        let ts: Date = (sampleObj.value(forKey: "startDate") as? Date)
                    ?? (sampleObj.value(forKey: "timestamp") as? Date)
                    ?? Date.distantPast

        // Illuminance in lux: try common keys
        let luxKeys = ["lux", "illuminance", "sphericalLux", "ambientLux"]
        let lux: Double? = luxKeys
            .compactMap { sampleObj.value(forKey: $0) as? Double }
            .first

        // Correlated Color Temperature (Kelvin): optional
        let cctKeys = ["colorTemperature", "cct", "correlatedColorTemperature", "cctK"]
        let cct: Double? = cctKeys
            .compactMap { sampleObj.value(forKey: $0) as? Double }
            .first

        // Build record only if we found at least the illuminance
        if let lux = lux {
            var record: [String: Any] = [
                "t": ISO8601Strategy.encode(ts),
                "lux": lux,
                "unit": "lux",
                "device_kind": "iphone"
            ]
            if let cct = cct {
                record["cct"] = cct
                record["cct_unit"] = "K"
            }
            self.collected.append(record)
        }

        return true // continue fetching
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
