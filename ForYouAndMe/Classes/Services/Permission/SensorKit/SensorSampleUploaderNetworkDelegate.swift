//
//  SensorSampleUploaderNetworkDelegate.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import RxSwift
import SensorKit

/// Network delegate used by SensorSampleUploadManager to upload one batch per call.
/// Implement this in termini della tua infrastruttura di rete (Moya/URLSession).
public protocol SensorSampleUploaderNetworkDelegate: AnyObject {
    /// Upload a single batch of records for a given sensor.
    /// - Parameters:
    ///   - sensor: The sensor these records belong to.
    ///   - payload: Array of JSON-ready dictionaries (safe to JSON-encode).
    /// - Returns: Single<Void> that completes when the server acknowledges the batch.
    func uploadSensorBatch(sensor: SRSensor, payload: [[String: Any]]) -> Single<Void>
}
