//
//  SensorSampleMapper.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation

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
