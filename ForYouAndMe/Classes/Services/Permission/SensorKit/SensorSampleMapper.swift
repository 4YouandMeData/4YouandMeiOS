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
    ///   - completion: Called on completion with either the mapped records or an error.
    func fetchAndMap(from: Date, to: Date, completion: @escaping (Result<[[String: Any]], Error>) -> Void)
}
