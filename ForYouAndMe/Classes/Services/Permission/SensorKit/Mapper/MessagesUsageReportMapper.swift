//
//  MessagesUsageReportMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit
import CoreMotion

/// Maps SensorKit messages usage aggregated reports into JSON-ready records.
/// Uses KVC to stay resilient across SDK field/name variations.
final class MessagesUsageReportMapper: NSObject, SensorSampleMapper {

    // This mapper handles the messages usage aggregated report
    var sensor: SRSensor { .messagesUsageReport }

    private let reader = SRSensorReader(sensor: .messagesUsageReport)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "MessagesUsageReportMapper: concurrent fetch not supported")

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
extension MessagesUsageReportMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        if let obj = result.sample as? NSObject {
            if let rec = Self.mapMessagesUsage(obj) {
                collected.append(rec)
            }
        } else if let list = result.sample as? CMSensorDataList {
            // Iterate potential batched results via NSFastEnumeration wrapper
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapMessagesUsage(obj) {
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

    /// Extract common messages-usage metrics using KVC and normalize to stable keys.
    private static func mapMessagesUsage(_ obj: NSObject) -> [String: Any]? {
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

        // Aggregate counters (probe multiple aliases)
        let numericAliases: [(inKey: String, outKey: String)] = [
            // totals
            ("totalMessages",      "messages"),
            ("messageCount",       "messages"),
            // sent / received
            ("messagesSent",       "messages_sent"),
            ("sentMessages",       "messages_sent"),
            ("messagesReceived",   "messages_received"),
            ("receivedMessages",   "messages_received"),
            // attachments
            ("attachmentsCount",   "attachments"),
            ("totalAttachments",   "attachments"),
            // conversations
            ("conversationsCount", "conversations"),
            ("totalConversations", "conversations")
        ]
        for pair in numericAliases {
            if let n = obj.value(forKey: pair.inKey) as? NSNumber {
                rec[pair.outKey] = n.intValue
            }
        }

        // Optional breakdown per-app / per-service
        // Common containers: "applications", "services", "messagingApps"
        if let apps = (obj.value(forKey: "applications") as? NSArray)
                   ?? (obj.value(forKey: "services") as? NSArray)
                   ?? (obj.value(forKey: "messagingApps") as? NSArray) {
            var arr: [[String: Any]] = []
            for any in apps {
                guard let app = any as? NSObject else { continue }
                let bundle = (app.value(forKey: "bundleIdentifier") as? String)
                          ?? (app.value(forKey: "bundleId") as? String)
                let total  = (app.value(forKey: "messageCount") as? NSNumber)?.intValue
                          ?? (app.value(forKey: "totalMessages") as? NSNumber)?.intValue
                let sent   = (app.value(forKey: "messagesSent") as? NSNumber)?.intValue
                          ?? (app.value(forKey: "sentMessages") as? NSNumber)?.intValue
                let recv   = (app.value(forKey: "messagesReceived") as? NSNumber)?.intValue
                          ?? (app.value(forKey: "receivedMessages") as? NSNumber)?.intValue
                let att    = (app.value(forKey: "attachmentsCount") as? NSNumber)?.intValue
                          ?? (app.value(forKey: "totalAttachments") as? NSNumber)?.intValue

                var entry: [String: Any] = [:]
                if let b = bundle { entry["bundle_id"] = b }
                if let t = total  { entry["messages"] = t }
                if let s = sent   { entry["messages_sent"] = s }
                if let r = recv   { entry["messages_received"] = r }
                if let a = att    { entry["attachments"] = a }

                if !entry.isEmpty { arr.append(entry) }
            }
            if !arr.isEmpty { rec["apps"] = arr }
        }

        return rec
    }
}
