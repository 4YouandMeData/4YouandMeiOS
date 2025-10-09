//
//  KeyboardMetricsMapper.swift
//

import Foundation
import SensorKit

// MARK: - Date ⇄ SRAbsoluteTime helpers (top-level)

/* Converts Date to SRAbsoluteTime using CFAbsoluteTime epoch (2001-01-01). */
extension Date {
    /// CFAbsoluteTime (sec since 2001-01-01) → SRAbsoluteTime
    var srAbsoluteTime: SRAbsoluteTime {
        SRAbsoluteTime.fromCFAbsoluteTime(_cf: timeIntervalSinceReferenceDate)
    }
}

private func dateFromSRAbsoluteTime(_ srTime: SRAbsoluteTime) -> Date {
    let cf = srTime.toCFAbsoluteTime()
    return Date(timeIntervalSinceReferenceDate: cf)
}

// MARK: - Mapper

/// Maps SensorKit `SRKeyboardMetrics` into JSON-ready dictionaries.
/// NOTE: Authorization and `startRecording()` are handled elsewhere.
final class KeyboardMetricsMapper: NSObject, SensorSampleMapper {

    // Expose the sensor this mapper handles
    var sensor: SRSensor { .keyboardMetrics }

    private let reader = SRSensorReader(sensor: .keyboardMetrics)
    private var pendingCompletion: ((Result<[[String: Any]], Error>) -> Void)?
    private var collected = [[String: Any]]()

    // Apple withholds last 24h of SensorKit data (absolute hours)
    private static let holdingPeriod: TimeInterval = 24 * 60 * 60

    // MARK: - Errors

    private enum MapperError: LocalizedError {
        case busy
        case notAuthorized(sensor: SRSensor, status: SRAuthorizationStatus)

        var errorDescription: String? {
            switch self {
            case .busy:
                return "Mapper is busy: a fetch is already in flight."
            case let .notAuthorized(sensor, status):
                return "SensorKit not authorized for \(sensor). Status: \(status)."
            }
        }
    }

    // MARK: - SensorSampleMapper

    /// Fetch the given [from, to) window, honoring the 24h embargo and mapping SRKeyboardMetrics.
    func fetchAndMap(
        from: Date,
        to: Date,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        // Avoid crashing on concurrent calls
        guard pendingCompletion == nil else {
            completion(.failure(MapperError.busy))
            return
        }

        // Enforce embargo: do not read within last 24h
        let embargoCutoff = Date().addingTimeInterval(-Self.holdingPeriod)
        let safeTo = min(to, embargoCutoff)
        guard from < safeTo else {
            completion(.success([]))
            return
        }

        let req = SRFetchRequest()
        req.device = SRDevice.current
        req.from = from.srAbsoluteTime
        req.to = safeTo.srAbsoluteTime

        collected.removeAll(keepingCapacity: true)
        pendingCompletion = completion
        reader.delegate = self
        reader.fetch(req)
    }
}

// MARK: - SRSensorReaderDelegate

extension KeyboardMetricsMapper: SRSensorReaderDelegate {

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        didFetchResult result: SRFetchResult<AnyObject>
    ) -> Bool {
        // Attach SRFetchResult.timestamp as recorded_at
        let recordedAt = dateFromSRAbsoluteTime(result.timestamp)
        if let metrics = result.sample as? NSObject,
           let record = Self.mapKeyboardMetrics(metrics, recordedAt: recordedAt) {
            collected.append(record)
        }
        return true // continue
    }

    func sensorReader(
        _ reader: SRSensorReader,
        didCompleteFetch fetchRequest: SRFetchRequest
    ) {
        finish(.success(collected))
    }

    func sensorReader(
        _ reader: SRSensorReader,
        fetching fetchRequest: SRFetchRequest,
        failedWithError error: any Error
    ) {
        finish(.failure(error))
    }

    // Keep delegate cleanup and completion in one place to avoid duplication
    private func finish(_ result: Result<[[String: Any]], Error>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        collected.removeAll(keepingCapacity: false)
        reader.delegate = nil
        completion?(result)
    }
}

// MARK: - Mapping (documented keys + quantitative + probability metrics)

private extension KeyboardMetricsMapper {

    // MARK: Safe KVC

    /// Call value(forKey:) only if selector exists (avoids KVC crashes).
    static func valueIfResponds(_ obj: NSObject, _ key: String) -> Any? {
        let sel = NSSelectorFromString(key)
        guard obj.responds(to: sel) else { return nil }
        return obj.value(forKey: key)
    }

    static func number(_ obj: NSObject, key: String) -> NSNumber? {
        valueIfResponds(obj, key) as? NSNumber
    }

    static func string(_ obj: NSObject, key: String) -> String? {
        valueIfResponds(obj, key) as? String
    }

    static func date(_ obj: NSObject, key: String) -> Date? {
        valueIfResponds(obj, key) as? Date
    }

    // MARK: Measurement extractors

    /// Extract seconds from either Measurement<UnitDuration> or numeric TimeInterval.
    static func seconds(_ obj: NSObject, key: String) -> Double? {
        if let m = valueIfResponds(obj, key) as? Measurement<UnitDuration> {
            return m.converted(to: .seconds).value
        }
        if let n = number(obj, key: key) {
            return n.doubleValue
        }
        return nil
    }

    /// Extract meters from Measurement<UnitLength>; accept raw numeric as meters if present.
    static func meters(_ obj: NSObject, key: String) -> Double? {
        if let m = valueIfResponds(obj, key) as? Measurement<UnitLength> {
            return m.converted(to: .meters).value
        }
        if let n = number(obj, key: key) {
            return n.doubleValue
        }
        return nil
    }

    /// Extract millimeters from Measurement<UnitLength>; accept raw numeric as millimeters if present.
    static func millimeters(_ obj: NSObject, key: String) -> Double? {
        if let m = valueIfResponds(obj, key) as? Measurement<UnitLength> {
            return m.converted(to: .millimeters).value
        }
        if let n = number(obj, key: key) {
            return n.doubleValue
        }
        return nil
    }

    // MARK: Probability metrics (safe, no undefined KVC)

    /// Extract numeric samples from known ProbabilityMetric arrays.
    static func samplesArray(_ obj: NSObject, keys: [String]) -> [Double]? {
        for key in keys {
            guard let any = valueIfResponds(obj, key) else { continue }

            if let ns = any as? [NSNumber] { return ns.map(\.doubleValue) }

            if let durs = any as? [Measurement<UnitDuration>] {
                return durs.map { $0.converted(to: .seconds).value }
            }

            if let lens = any as? [Measurement<UnitLength>] {
                return lens.map { $0.converted(to: .meters).value }
            }
        }
        return nil
    }

    /// Compute basic stats from raw samples.
    static func summarize(_ values: [Double]) -> [String: Any] {
        guard !values.isEmpty else { return ["count": 0] }

        let n = Double(values.count)
        let mean = values.reduce(0, +) / n
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / n
        let std = sqrt(variance)
        let sorted = values.sorted()

        func pct(_ p: Double) -> Double {
            let idx = max(0, min(sorted.count - 1,
                                 Int(round((p / 100.0) * Double(sorted.count - 1)))))
            return sorted[idx]
        }

        return [
            "count": values.count,
            "mean": mean,
            "median": pct(50),
            "std": std,
            "min": sorted.first ?? mean,
            "max": sorted.last ?? mean,
            "p90": pct(90),
            "p95": pct(95)
        ]
    }

    /// Robust export that never KVC-crashes on undefined keys.
    static func exportProbabilityMetric(_ any: Any?) -> [String: Any]? {
        guard let metric = any as? NSObject else { return nil }

        // Pull samples from any of the documented properties
        guard let samples = samplesArray(
            metric,
            keys: ["sampleValues", "distributionSampleValues", "values"]
        ) else {
            return nil
        }

        var out = summarize(samples)

        // Attach unit if present (best effort)
        if let unit = valueIfResponds(metric, "unit") {
            switch unit {
            case is UnitDuration: out["unit"] = "seconds"
            case is UnitLength: out["unit"] = "meters"
            default: out["unit"] = String(describing: type(of: unit))
            }
        }

        // Pass-through percentiles/histogram if exposed
        if let p = valueIfResponds(metric, "percentiles") as? [NSNumber] { out["percentiles"] = p }
        if let h = valueIfResponds(metric, "histogram") as? [NSNumber] { out["histogram"] = h }

        return out
    }

    // MARK: Mapping SRKeyboardMetrics

    static let probabilityMetricKeys: [String] = [
        // Key-to-key timings
        "spaceToCharKey",
        "charKeyToCharKey",
        "charKeyToPrediction",
        "charKeyToDeleteKey",
        "deleteToCharKey",
        "spaceToDeleteKey",
        "charKeyToPlaneChangeKey",
        "planeChangeKeyToCharKey",
        // Touch durations (down/up)
        "touchDownUp",
        "touchUpDown",
        // Error distances
        "shortWordCharKeyDownErrorDistance",
        "shortWordCharKeyUpErrorDistance",
        "longWordCharKeyDownErrorDistance",
        "longWordCharKeyUpErrorDistance",
        "deleteDownErrorDistance",
        "spaceDownErrorDistance",
        // Path/gesture
        "pathToPath"
    ]

    /// Map SRKeyboardMetrics -> flat JSON (documented keys + quantitative + probability).
    static func mapKeyboardMetrics(
        _ obj: NSObject,
        recordedAt: Date?
    ) -> [String: Any]? {
        // Be conservative on type acceptance
        let typeName = NSStringFromClass(type(of: obj))
        guard typeName.contains("KeyboardMetrics") else { return nil }

        let iso = ISO8601DateFormatter()
        var rec: [String: Any] = [:]

        // Recorded-at from SRFetchResult.timestamp
        if let ts = recordedAt { rec["recorded_at"] = iso.string(from: ts) }

        // Period bounds
        if let start = date(obj, key: "startDate") { rec["start"] = iso.string(from: start) }
        if let end = date(obj, key: "endDate") { rec["end"] = iso.string(from: end) }
        if let dur = seconds(obj, key: "duration") { rec["duration_s"] = dur }

        // Identifiers & metadata
        if let version = number(obj, key: "version")?.intValue { rec["version"] = version }
        if let sessions = valueIfResponds(obj, "sessionIdentifiers") as? [String] {
            rec["sessionIdentifiers"] = sessions
        }
        if let kbId = string(obj, key: "keyboardIdentifier") { rec["keyboardIdentifier"] = kbId }
        if let lang = string(obj, key: "primaryLanguage")
            ?? string(obj, key: "keyboardPrimaryLanguage") {
            rec["primaryLanguage"] = lang
        }
        if let layout = string(obj, key: "keyboardLayout") { rec["keyboardLayout"] = layout }
        if let width = millimeters(obj, key: "width") { rec["width_mm"] = width }
        if let height = millimeters(obj, key: "height") { rec["height_mm"] = height }

        // Quantitative counts
        let countMap: [(String, String)] = [
            ("totalWords", "total_words"),
            ("totalAlteredWords", "total_altered_words"),
            ("totalTaps", "total_taps"),
            ("totalDrags", "total_drags"),
            ("totalPaths", "total_paths"),
            ("totalPathPauses", "total_path_pauses"),
            ("totalPauses", "total_pauses"),
            ("totalTypingEpisodes", "total_typing_episodes"),
            ("totalEmojis", "total_emojis"),
            ("totalInsertKeyCorrections", "total_insert_key_corrections"),
            ("totalNearKeyCorrections", "total_near_key_corrections"),
            ("totalSkipTouchCorrections", "total_skip_touch_corrections"),
            ("totalAutoCorrections", "total_autocorrections"),
            ("totalTranspositionCorrections", "total_transposition_corrections"),
            ("totalSpaceCorrections", "total_space_corrections"),
            ("totalDeletes", "total_deletes")
        ]
        for (src, dst) in countMap {
            if let v = number(obj, key: src)?.intValue { rec[dst] = v }
        }

        // Quantitative durations / lengths
        if let typing = seconds(obj, key: "totalTypingDuration") {
            rec["total_typing_duration_s"] = typing
        }
        if let pathTime = seconds(obj, key: "totalPathTime") {
            rec["total_path_time_s"] = pathTime
        }
        if let pathLen = meters(obj, key: "totalPathLength") {
            rec["total_path_length_m"] = pathLen
        }

        // Probability metrics (summarized)
        var pm = [String: Any]()
        for key in probabilityMetricKeys {
            if let dict = exportProbabilityMetric(valueIfResponds(obj, key)) {
                pm[key] = dict
            }
        }
        if !pm.isEmpty { rec["probabilityMetrics"] = pm }

        rec["device_kind"] = "iphone"
        return rec
    }
}
