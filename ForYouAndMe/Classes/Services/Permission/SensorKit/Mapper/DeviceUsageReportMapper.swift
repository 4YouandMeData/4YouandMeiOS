//
//  DeviceUsageReportMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit
import CoreMotion

/// Maps SensorKit device usage report samples into JSON-ready records.
/// Robust to SDK changes via KVC: we probe multiple known keys.
final class DeviceUsageReportMapper: NSObject, SensorSampleMapper {

    // This mapper handles the device usage aggregated report
    var sensor: SRSensor { .deviceUsageReport }

    private let reader = SRSensorReader(sensor: .deviceUsageReport)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String : Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "DeviceUsageReportMapper: concurrent fetch not supported")

        // Respect the 24h holding period for SensorKit data
        let safeTo = min(to, Date().addingTimeInterval(-Self.holdingPeriod))
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        let req = SRFetchRequest()
        req.device = SRDevice.current
        // Convert Date -> SRAbsoluteTime (CFAbsoluteTime since 2001-01-01)
        req.from = SRAbsoluteTime.fromCFAbsoluteTime(_cf: from.timeIntervalSinceReferenceDate)
        req.to   = SRAbsoluteTime.fromCFAbsoluteTime(_cf: safeTo.timeIntervalSinceReferenceDate)

        collected.removeAll(keepingCapacity: true)
        pendingCompletion = completion
        reader.delegate = self
        reader.fetch(req) // delegate-based API
    }
}

// MARK: - SRSensorReaderDelegate
extension DeviceUsageReportMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        // Reports may arrive one-by-one as NSObject-like samples
        if let obj = result.sample as? NSObject {
            if let rec = Self.mapDeviceUsage(obj) {
                collected.append(rec)
            }
        } else if let list = result.sample as? CMSensorDataList {
            // Fallback: rarely a list; iterate via NSFastEnumeration wrapper
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapDeviceUsage(obj) {
                    collected.append(rec)
                }
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

    /// Extracts common device-usage metrics using KVC to stay resilient across SDK versions.
    private static func mapDeviceUsage(_ obj: NSObject) -> [String: Any]? {
        let fmt = ISO8601DateFormatter()

        // Time bounds (best-effort)
        let start: Date = (obj.value(forKey: "startDate") as? Date)
                       ?? (obj.value(forKey: "start") as? Date)
                       ?? Date.distantPast
        let end:   Date = (obj.value(forKey: "endDate") as? Date)
                       ?? (obj.value(forKey: "end") as? Date)
                       ?? start

        var rec: [String: Any] = [
            "start": fmt.string(from: start),
            "end":   fmt.string(from: end),
            "device_kind": "iphone"
        ]

        // Common top-level counters/durations (seconds or counts)
        // We probe multiple aliases and normalize names.
        let numericAliases: [(inKey: String, outKey: String)] = [
            ("totalScreenWakes", "screen_wakes"),
            ("screenWakes",      "screen_wakes"),
            ("totalUnlocks",     "unlocks"),
            ("unlockCount",      "unlocks"),
            ("totalScreenTime",  "screen_on_s"),   // seconds
            ("screenOnDuration", "screen_on_s"),   // seconds
            ("totalNotifications","notifications"),
            ("notificationsCount","notifications"),
            ("pickups",          "pickups")
        ]

        for pair in numericAliases {
            if let n = obj.value(forKey: pair.inKey) as? NSNumber {
                // Heuristic: durations stay Double, counters Int
                if pair.outKey.hasSuffix("_s") {
                    rec[pair.outKey] = n.doubleValue
                } else {
                    rec[pair.outKey] = n.intValue
                }
            }
        }

        // Per-app breakdown (if available): array of app usage entries
        if let apps = obj.value(forKey: "applications") as? NSArray {
            var appArr: [[String: Any]] = []
            for any in apps {
                guard let app = any as? NSObject else { continue }
                let bundle = (app.value(forKey: "bundleIdentifier") as? String)
                          ?? (app.value(forKey: "bundleId") as? String)

                let usageSeconds = (app.value(forKey: "usageTime") as? NSNumber)?.doubleValue
                                ?? (app.value(forKey: "totalUsageTime") as? NSNumber)?.doubleValue

                let notifCount = (app.value(forKey: "notifications") as? NSNumber)?.intValue
                               ?? (app.value(forKey: "notificationsCount") as? NSNumber)?.intValue

                var entry: [String: Any] = [:]
                if let b = bundle { entry["bundle_id"] = b }
                if let u = usageSeconds { entry["usage_s"] = u }
                if let c = notifCount { entry["notifications"] = c }

                if !entry.isEmpty { appArr.append(entry) }
            }
            if !appArr.isEmpty {
                rec["apps"] = appArr
            }
        }

        // If we only have start/end with nothing else, still return (server can aggregate).
        return rec
    }
}
