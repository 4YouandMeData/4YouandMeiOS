//
//  AccelerometerMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit
import CoreMotion


private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

// MARK: - Mapper

/// Maps SensorKit Accelerometer samples (CMRecordedAccelerometerData) into JSON-ready payloads.
/// NOTE: Authorization request and `startRecording()` are handled elsewhere.
final class AccelerometerMapper: NSObject, SensorSampleMapper {

    var sensor: SRSensor { .accelerometer }

    private let reader = SRSensorReader(sensor: .accelerometer)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected = [[String: Any]]()
    private var fetchedResults = 0

    // Apple withholds last 24h of SensorKit data (absolute hours)
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
                return "SensorKit not authorized for accelerometer. Status: \(status)."
            }
        }
    }

    // MARK: - SensorSampleMapper

    /// Fetch [from, to) honoring the 24h embargo and map CMRecordedAccelerometerData records.
    func fetchAndMap(
        from: Date,
        to: Date,
        device: SensorDevice,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        // Avoid concurrent fetches
        guard pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Enforce embargo: do not read within last 24h
        // F10 (review round 1; wording corrected round 3): the best clock available, not the raw
        // device clock. An improvement, not immunity: ServerClock.now() is Date() + storedOffset,
        // so a rollback lowers BOTH operands until the next API response re-records the offset —
        // inside that gap the cutoff can still truncate the planned span (the manager would treat
        // the partial result as the whole window). The planner owns embargo policy; this stays as
        // defence in depth.
        let embargoCutoff = max(Date(), ServerClock.now()).addingTimeInterval(-Self.holdingPeriod)
        let safeTo = min(to, embargoCutoff)
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        // Build request
        let req = SRFetchRequest()
        // FUAM-3945: iPhone or paired Watch — the manager walks one device at a time.
        req.device = device.fetchTarget
        req.from = from.srAbsoluteTime
        req.to = safeTo.srAbsoluteTime

        collected.removeAll(keepingCapacity: true)
        fetchedResults = 0
        pendingCompletion = completion
        reader.delegate = self
        reader.fetch(req)
    }
}

// MARK: - SRSensorReaderDelegate

extension AccelerometerMapper: SRSensorReaderDelegate {

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        didFetchResult result: SRFetchResult<AnyObject>
    ) -> Bool {
        // `result.sample` for accelerometer is typically CMSensorDataList of CMRecordedAccelerometerData.
        // Attach SRFetchResult.timestamp to each record as recorded_at (batch's record time).
        let recordedAtISO: String = {
            let iso = ISO8601DateFormatter()
            return iso.string(from: dateFromSRAbsoluteTime(result.timestamp))
        }()

        fetchedResults += 1

        var records: [[String: Any]] = []
        if let list = result.sample as? CMSensorDataList {
            for element in FastEnumerationSequence(base: list) {
                guard let item = element as? CMRecordedAccelerometerData else { continue }
                records.append(record(from: item, recordedAtISO: recordedAtISO))
            }
        } else if let item = result.sample as? CMRecordedAccelerometerData {
            records.append(record(from: item, recordedAtISO: recordedAtISO))
        }
        // FUAM-3945: ledger identity — the raw monotonic timestamp, never its wall
        // projection (see SensorRecordIdentity). The raw value ships only when it identifies a
        // single record; list siblings share it.
        collected.append(contentsOf: SensorRecordIdentity.stampedResult(records,
                                                                         raw: result.timestamp,
                                                                         replacing: ["recorded_at"]))
        // Keep fetching subsequent chunks
        return true
    }

    func sensorReader(
        _ reader: SRSensorReader,
        didCompleteFetch fetchRequest: SRFetchRequest
    ) {
        finish(self.classifyFetchOutcome(collected: collected, fetchedResults: fetchedResults))
    }

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        failedWithError error: Error
    ) {
        finish(.failure(error))
    }

    // MARK: - Helpers

    /// Build one JSON record from a CMRecordedAccelerometerData sample.
    private func record(from sample: CMRecordedAccelerometerData, recordedAtISO: String) -> [String: Any] {
        // CMAcceleration is expressed in g's (unitless gravitational acceleration).
        let a = sample.acceleration
        let iso = ISO8601DateFormatter()
        return [
            // Sample timestamp (when motion was measured) — a stored Foundation date,
            // fetch-stable, so it stays in the ledger fingerprint untouched.
            "t": iso.string(from: sample.startDate),
            // Batch record time from SRFetchResult.timestamp (useful for auditing)
            "recorded_at": recordedAtISO,
            // Raw axes
            "x": a.x,
            "y": a.y,
            "z": a.z
        ]
    }

    /// Centralized cleanup + callback.
    private func finish(_ result: Result<[[String: Any]], Error>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        reader.delegate = nil
        completion?(result)
    }
}

// MARK: - NSFastEnumeration → Swift Sequence wrapper

/// Generic wrapper to iterate any Objective-C NSFastEnumeration in Swift.
struct FastEnumerationSequence: Sequence {
    let base: NSFastEnumeration
    typealias Iterator = NSFastEnumerationIterator
    func makeIterator() -> NSFastEnumerationIterator { NSFastEnumerationIterator(base) }
}
