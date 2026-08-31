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
/// (`SensorUploadLedger.fetchStableForm`); the drain strips both companion keys from every
/// outgoing payload (`SensorSampleUploadManager.drainQueue`), so they can never reach the server.
enum SensorRecordIdentity {

    /// `SRFetchResult.timestamp.rawValue` — monotonic seconds, fetch-stable. Never uploaded.
    static let rawKey = "_sr_raw_timestamp"
    /// The wall-projected keys `rawKey` stands in for inside the fingerprint. Never uploaded.
    static let replacesKey = "_sr_raw_replaces"

    /// The record with its fetch-stable identity companions attached.
    static func stamped(_ record: [String: Any],
                        raw: SRAbsoluteTime,
                        replacing keys: [String]) -> [String: Any] {
        var out = record
        out[Self.rawKey] = raw.rawValue
        out[Self.replacesKey] = keys
        return out
    }

    /// The records exactly as uploaded: no identity companions. Idempotent — a record enqueued
    /// by a pre-fix build simply has nothing to strip.
    static func stripped(_ records: [[String: Any]]) -> [[String: Any]] {
        return records.map { record in
            var out = record
            out.removeValue(forKey: Self.rawKey)
            out.removeValue(forKey: Self.replacesKey)
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
