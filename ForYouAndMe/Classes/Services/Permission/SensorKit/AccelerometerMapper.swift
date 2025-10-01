//
//  AccelerometerMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit
import CoreMotion

/// Maps SensorKit accelerometer samples to network-ready payloads.
final class AccelerometerMapper: NSObject, SensorSampleMapper {

    var sensor: SRSensor { .accelerometer }

    private let reader = SRSensorReader(sensor: .accelerometer)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date, to: Date, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        precondition(pendingCompletion == nil, "AccelerometerMapper: concurrent fetch not supported")

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

extension AccelerometerMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {
        // For accelerometer, result.sample is CMSensorDataList of CMRecordedAccelerometerData
        if let list = result.sample as? CMSensorDataList {
            // Iterate using the wrapper to avoid extending imported types
            for element in FastEnumerationSequence(base: list) {
                guard let item = element as? CMRecordedAccelerometerData else { continue }
                let a = item.acceleration
                let ts = item.startDate
                let record: [String: Any] = [
                    // ISO8601 string keeps backend consistent
                    "t": ISO8601Strategy.encode(ts),
                    "x": a.x,
                    "y": a.y,
                    "z": a.z,
                    "device_kind": "iphone"
                ]
                self.collected.append(record)
            }
        }
        // Continue fetching subsequent chunks
        return true
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

/// Generic wrapper to iterate any Objective-C NSFastEnumeration in Swift.
/// Usage:
///   for element in FastEnumerationSequence(base: someFastEnum) { ... }
struct FastEnumerationSequence: Sequence {
    let base: NSFastEnumeration

    typealias Iterator = NSFastEnumerationIterator
    func makeIterator() -> NSFastEnumerationIterator {
        return NSFastEnumerationIterator(base)
    }
}
