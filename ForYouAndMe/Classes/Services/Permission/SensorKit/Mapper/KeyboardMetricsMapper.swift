//
//  KeyboardMetricsMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//


import Foundation
import SensorKit
import CoreMotion

/// Maps SensorKit keyboard metrics into JSON-ready records.
/// We rely on KVC to remain resilient across SDK changes.
/// NOTE: Apple impone un embargo ~24h sui dati SensorKit.
final class KeyboardMetricsMapper: NSObject, SensorSampleMapper {

    // This mapper handles the keyboard metrics stream
    var sensor: SRSensor { .keyboardMetrics }

    private let reader = SRSensorReader(sensor: .keyboardMetrics)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected: [[String: Any]] = []

    // Apple withholds last 24h of SensorKit data
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    func fetchAndMap(from: Date,
                     to: Date,
                     completion: @escaping (Result<[[String : Any]], Error>) -> Void) {

        precondition(pendingCompletion == nil, "KeyboardMetricsMapper: concurrent fetch not supported")

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
        reader.fetch(req) // delegate-based API (no trailing closure)
    }
}

// MARK: - SRSensorReaderDelegate
extension KeyboardMetricsMapper: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader,
                      fetching fetchRequest: SRFetchRequest,
                      didFetchResult result: SRFetchResult<AnyObject>) -> Bool {

        if let obj = result.sample as? NSObject {
            if let rec = Self.mapKeyboardMetrics(obj) {
                collected.append(rec)
            }
        } else if let list = result.sample as? CMSensorDataList {
            // Iterate list via NSFastEnumeration wrapper (già definita altrove nel progetto)
            for element in FastEnumerationSequence(base: list) {
                guard let obj = element as? NSObject else { continue }
                if let rec = Self.mapKeyboardMetrics(obj) {
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

    /// KVC-based extractor; normalizza i campi a chiavi stabili.
    private static func mapKeyboardMetrics(_ obj: NSObject) -> [String: Any]? {
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

        // Aggregate counters/durations — we probe multiple aliases
        let intAliases: [(String, String)] = [
            ("totalKeystrokes", "keystrokes"),
            ("keystrokes",      "keystrokes"),
            ("backspaceCount",  "deletes"),
            ("deleteCount",     "deletes"),
            ("autoCorrections", "autocorrections"),
            ("autocorrections", "autocorrections"),
            ("predictionAccepts","predictions_accepted"),
            ("predictionsAccepted","predictions_accepted"),
            ("emojiCount",      "emojis"),
            ("pasteCount",      "pastes"),
            ("copyCount",       "copies"),
            ("cutCount",        "cuts"),
            ("sessionCount",    "sessions")
        ]
        for (inKey, outKey) in intAliases {
            if let n = obj.value(forKey: inKey) as? NSNumber {
                rec[outKey] = n.intValue
            }
        }

        let doubleAliases: [(String, String)] = [
            ("typingDuration",  "typing_duration_s"),
            ("totalTypingTime", "typing_duration_s"),
            ("dictationDuration","dictation_s"),
            ("dictationTime",   "dictation_s"),
            ("averageKeystrokesPerMinute", "kpm") // keys per minute
        ]
        for (inKey, outKey) in doubleAliases {
            if let n = obj.value(forKey: inKey) as? NSNumber {
                rec[outKey] = n.doubleValue
            }
        }

        // Optional per-keyboard breakdown (e.g., per lingua o per layout)
        if let keyboards = (obj.value(forKey: "keyboards") as? NSArray)
                        ?? (obj.value(forKey: "layouts") as? NSArray) {
            var arr: [[String: Any]] = []
            for any in keyboards {
                guard let kb = any as? NSObject else { continue }
                let id   = (kb.value(forKey: "identifier") as? String)
                        ?? (kb.value(forKey: "keyboardIdentifier") as? String)
                        ?? (kb.value(forKey: "primaryLanguage") as? String)
                let kNum = (kb.value(forKey: "keystrokes") as? NSNumber)?.intValue
                        ?? (kb.value(forKey: "totalKeystrokes") as? NSNumber)?.intValue
                let del  = (kb.value(forKey: "backspaceCount") as? NSNumber)?.intValue
                        ?? (kb.value(forKey: "deleteCount") as? NSNumber)?.intValue
                let auto = (kb.value(forKey: "autocorrections") as? NSNumber)?.intValue
                        ?? (kb.value(forKey: "autoCorrections") as? NSNumber)?.intValue
                let dur  = (kb.value(forKey: "typingDuration") as? NSNumber)?.doubleValue
                        ?? (kb.value(forKey: "totalTypingTime") as? NSNumber)?.doubleValue

                var entry: [String: Any] = [:]
                if let id = id { entry["id"] = id }
                if let k  = kNum { entry["keystrokes"] = k }
                if let d  = del  { entry["deletes"] = d }
                if let a  = auto { entry["autocorrections"] = a }
                if let t  = dur  { entry["typing_duration_s"] = t }
                if !entry.isEmpty { arr.append(entry) }
            }
            if !arr.isEmpty { rec["keyboards"] = arr }
        }

        return rec
    }
}
