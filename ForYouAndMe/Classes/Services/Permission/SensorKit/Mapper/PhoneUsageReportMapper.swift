//
//  PhoneUsageReportMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit
import CoreMotion

/// Maps SensorKit phone usage aggregated reports into JSON-ready records.
/// We use KVC to stay resilient across potential SDK field changes.
final class PhoneUsageReportMapper: NSObject, SensorSampleMapper {

    // This mapper handles the phone usage aggregated report
    var sensor: SRSensor { .phoneUsageReport }

    private let reader = SRSensorReader(sensor: .phoneUsageReport)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String : Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "PhoneUsageReportMapper: concurrent fetch not supported")

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
extension PhoneUsageReportMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        if let obj = result.sample as? NSObject {
            if let rec = Self.mapPhoneUsage(obj) {
                collected.append(rec)
            }
        } else if let list = result.sample as? CMSensorDataList {
            // If the SDK ever wraps multiple items in a list, iterate it
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapPhoneUsage(obj) {
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

    /// Extract common phone-usage metrics (calls, durations, breakdown) using KVC.
    /// We normalize a small set of fields to stable keys.
    private static func mapPhoneUsage(_ obj: NSObject) -> [String: Any]? {
        let fmt = ISO8601DateFormatter()

        // Time bounds
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

        // Aggregate counters/durations (we probe multiple aliases)
        let numericAliases: [(inKey: String, outKey: String, isDuration: Bool)] = [
            // total calls
            ("totalCalls",           "calls",           false),
            ("callCount",            "calls",           false),
            // incoming / outgoing
            ("incomingCalls",        "incoming_calls",  false),
            ("totalIncomingCalls",   "incoming_calls",  false),
            ("outgoingCalls",        "outgoing_calls",  false),
            ("totalOutgoingCalls",   "outgoing_calls",  false),
            // total duration (seconds)
            ("totalCallDuration",    "call_duration_s", true),
            ("callsDuration",        "call_duration_s", true),
            // voip/facetime/cellular breakdowns (seconds)
            ("voipCallDuration",         "voip_duration_s",       true),
            ("totalVoIPCallDuration",    "voip_duration_s",       true),
            ("faceTimeAudioDuration",    "facetime_audio_s",      true),
            ("faceTimeVideoDuration",    "facetime_video_s",      true),
            ("cellularCallDuration",     "cellular_call_s",       true)
        ]

        for a in numericAliases {
            if let n = obj.value(forKey: a.inKey) as? NSNumber {
                rec[a.outKey] = a.isDuration ? n.doubleValue : n.intValue
            }
        }

        // Optional per-app/ per-service breakdown
        // Common containers: "applications" / "services" / "communicationApps"
        if let apps = (obj.value(forKey: "applications") as? NSArray)
                   ?? (obj.value(forKey: "services") as? NSArray)
                   ?? (obj.value(forKey: "communicationApps") as? NSArray) {
            var arr: [[String: Any]] = []
            for any in apps {
                guard let app = any as? NSObject else { continue }
                let bundle = (app.value(forKey: "bundleIdentifier") as? String)
                          ?? (app.value(forKey: "bundleId") as? String)
                let cnt    = (app.value(forKey: "callCount") as? NSNumber)?.intValue
                let dur    = (app.value(forKey: "callDuration") as? NSNumber)?.doubleValue
                          ?? (app.value(forKey: "totalCallDuration") as? NSNumber)?.doubleValue

                var entry: [String: Any] = [:]
                if let b = bundle { entry["bundle_id"] = b }
                if let c = cnt    { entry["calls"] = c }
                if let d = dur    { entry["duration_s"] = d }
                if !entry.isEmpty { arr.append(entry) }
            }
            if !arr.isEmpty { rec["apps"] = arr }
        }

        return rec
    }
}
