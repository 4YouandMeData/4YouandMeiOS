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
