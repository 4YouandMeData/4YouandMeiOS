//
//  SensorSampleMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import SensorKit

/// FUAM-3945: fetch-stable record identity.
///
/// `SRFetchResult.timestamp` is an `SRAbsoluteTime` — a monotonic clock value that "ticks across
/// sleeps and reboots" (SRAbsoluteTime.h). `toCFAbsoluteTime()` projects it onto the wall clock
/// AT CONVERSION TIME, so the same stored sample converts to a DIFFERENT wall instant whenever
/// the device's wall-vs-monotonic offset moved between two fetches — any NTP step or slew
/// (measured ~1 s over 2 days on the production device). The uploaded `recorded_at` /
/// `recorded_at_precise` keys must keep that projection (the server derives the row anchor from
/// them, and the payload shape is contractual), but the D4 upload ledger must NOT hash it: an
/// offset movement of 1 ms would invalidate every fingerprint and make the daily rescan
/// re-upload its whole tail as "novel" — the exact duplication the ledger exists to prevent.
///
/// Each mapper therefore stamps every record with the raw, unprojected value under `rawKey` and
/// lists the wall-projected keys that value stands in for under `replacesKey`. The ledger hashes
/// the record with the listed keys removed and the raw value kept
/// (`SensorUploadLedger.fetchStableForm`). The raw value SHIPS as `sr_absolute_time` — the
/// server needs the same fetch-stable identity for cross-row deduplication (FUAM-4030), because
/// its whole-element fingerprint suffers the exact drift described above — but ONLY on a record
/// that is the sole record of its fetch result. The backend (FUAM-4074) treats
/// `sr_absolute_time` as the identity of ONE record and collapses every element sharing it, so
/// the siblings of a fan-out result (one `SRFetchResult` mapped to several records: ambient
/// pressure, accelerometer, rotation rate, the list branches of pedometer and media events)
/// keep the raw value locally for the ledger, marked with `localOnlyKey`, and upload WITHOUT
/// it; the server then identifies them by content digest. A mapper whose result can hold
/// several samples must stamp through `stampedResult(_:raw:replacing:)`, which applies that rule. The `replacesKey` and
/// `localOnlyKey` bookkeeping is stripped before upload (`SensorSampleUploadManager.drainQueue`);
/// it never reaches the server.
enum SensorRecordIdentity {

    /// `SRFetchResult.timestamp.rawValue` — `SRAbsoluteTime` in seconds (Double). UPLOADED only
    /// on a record that is the SOLE record of its fetch result, where it identifies exactly that
    /// record; absent from every record of a fan-out result (see `localOnlyKey`). For analysts
    /// and the backend: this is a MONOTONIC DEVICE CLOCK value that ticks across sleeps and
    /// reboots (SRAbsoluteTime.h) — a fetch-stable deduplication identity for ONE record,
    /// nothing more. It is NOT a date, NOT comparable across devices, and NEVER a substitute for
    /// `recorded_at` (which stays the row-anchor source, byte-for-byte unchanged).
    static let rawKey = "sr_absolute_time"
    /// The wall-projected keys `rawKey` stands in for inside the fingerprint. Internal
    /// bookkeeping — never uploaded.
    static let replacesKey = "_sr_raw_replaces"
    /// Marks a record whose `rawKey` is shared with sibling records of the same fetch result:
    /// the ledger still hashes the raw value (content discriminates the siblings), but `rawKey`
    /// is removed before upload so the backend does not collapse the siblings into one record.
    /// Internal bookkeeping — never uploaded.
    static let localOnlyKey = "_sr_raw_local_only"

    /// Every record mapped from ONE fetch result, stamped. A single record keeps `rawKey` for
    /// upload; several records (siblings sharing one `SRFetchResult.timestamp`) are marked
    /// `localOnlyKey` so `stripped` drops `rawKey` from each of them before upload.
    static func stampedResult(_ records: [[String: Any]],
                              raw: SRAbsoluteTime,
                              replacing keys: [String]) -> [[String: Any]] {
        let shared = records.count > 1
        return records.map { record in
            var out = Self.stamped(record, raw: raw, replacing: keys)
            if shared { out[Self.localOnlyKey] = true }
            return out
        }
    }

    /// The record with its fetch-stable identity companions attached. Only for a result that
    /// can never hold more than one record; a fan-out mapper uses `stampedResult`.
    static func stamped(_ record: [String: Any],
                        raw: SRAbsoluteTime,
                        replacing keys: [String]) -> [String: Any] {
        var out = record
        out[Self.rawKey] = raw.rawValue
        out[Self.replacesKey] = keys
        return out
    }

    /// The records exactly as uploaded: `rawKey` (`sr_absolute_time`) stays on a sole record —
    /// it ships as the server-side dedup identity — and is removed from a fan-out sibling
    /// (`localOnlyKey`); the `replacesKey`/`localOnlyKey` bookkeeping is always removed.
    /// Idempotent; a record enqueued by a pre-fix build simply has nothing to strip. Also
    /// removes the pre-rename `_sr_raw_timestamp` a queue persisted by an interim dev build may
    /// still carry: that spelling was never meant to leave the device.
    static func stripped(_ records: [[String: Any]]) -> [[String: Any]] {
        return records.map { record in
            var out = record
            if out.removeValue(forKey: Self.localOnlyKey) != nil {
                out.removeValue(forKey: Self.rawKey)
            }
            out.removeValue(forKey: Self.replacesKey)
            out.removeValue(forKey: "_sr_raw_timestamp")
            return out
        }
    }
}

/// Maps raw SensorKit samples fetched over a [from, to) window into JSON-ready dictionaries.
/// Implementations will own the SRSensorReader and perform SRFetchRequest + mapping.
public protocol SensorSampleMapper: AnyObject {
    /// Fetch the window and map to an array of dictionaries suitable for JSON.
    /// - Parameters:
    ///   - from: Start date (inclusive/exclusive a seconda del tuo handling dei boundary)
    ///   - to: End date
    ///   - device: The SensorKit device to fetch from (FUAM-3945). SensorKit stores iPhone and
    ///     paired-Watch data separately and a fetch request targets exactly one of them, so this
    ///     is what makes a Watch stream reachable at all. Implementations must set
    ///     `SRFetchRequest.device = device.fetchTarget` and nothing else — the per-record device
    ///     tag is applied centrally by `SensorSampleUploadManager`.
    ///   - completion: Called on completion with either the mapped records or an error.
    func fetchAndMap(from: Date,
                     to: Date,
                     device: SensorDevice,
                     completion: @escaping (Result<[[String: Any]], Error>) -> Void)
}

/// FUAM-3945 (fidelity review R3): a completed fetch that returned results the mapper could not
/// turn into a single record is a PARSE FAILURE, not an empty window. The upload manager
/// classifies `.success([])` as CONFIRMED-EMPTY — the one condition allowed to advance the
/// cursor past a window (AC4) — so reporting unparsed results as an empty success would advance
/// the cursor permanently past real data, silently. Reporting them as a failure routes the
/// window through the bounded-retry path instead; a persistent parse failure then ends as a
/// LOUD `gave_up` forfeit trace, never an invisible loss.
struct SensorMapperUnparsedResultsError: LocalizedError {
    let fetchedResults: Int
    var errorDescription: String? {
        return "Fetch returned \(fetchedResults) result(s) but none could be mapped: parse failure, not an empty window."
    }
}

extension SensorSampleMapper {
    /// The completion classification every mapper shares on `didCompleteFetch` (see
    /// `SensorMapperUnparsedResultsError`). A fetch that saw NO results is a genuinely empty
    /// window; one that saw results but mapped nothing is not. An OS batch wrapper holding zero
    /// samples would land in the failure branch too — the cost there is a bounded retry and a
    /// loud forfeit, never data loss, which is the right trade against a silent cursor advance.
    func classifyFetchOutcome(collected: [[String: Any]], fetchedResults: Int) -> Result<[[String: Any]], Error> {
        if collected.isEmpty && fetchedResults > 0 {
            return .failure(SensorMapperUnparsedResultsError(fetchedResults: fetchedResults))
        }
        return .success(collected)
    }
}
