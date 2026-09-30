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

/// The server deliberately rejected a sensor batch (FUAM-3945 round 5, AC6): re-sending the
/// same bytes can never succeed, so these — and only these — count against the per-batch
/// upload budget in `SensorSampleUploadManager.drainQueue`. Everything else (connectivity,
/// 5xx, auth) stays on the unbounded backoff retry: a network outage must never burn the
/// budget. Emitted by `RepositoryImpl.uploadSensorNetworkData`, where the HTTP status code
/// still exists (`handleError` collapses `ApiError` into `RepositoryError`, which drops it).
enum SensorUploadError: Error {
    case permanentlyRejected(statusCode: Int)

    /// The "this payload is unacceptable" class: 400 (malformed), 413 (over the cap — normally
    /// pre-empted by the 5 MB client-side split), 422 (validation). Deliberately NOT included:
    /// 401 (re-auth recovers), 403 (clearance can change), 404/409/429/5xx (deploy blips, rate
    /// limits, outages — all transient).
    static let permanentRejectionStatusCodes: Set<Int> = [400, 413, 422]
}
