//
//  SensorSampleUploadManagerReachability.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import RxSwift
import Network

/// Reachability abstraction used by the SensorKit upload manager.
/// It mirrors your Health side reachability concept.
public protocol SensorSampleUploadManagerReachability: AnyObject {
    /// Current network reachability flag.
    var isReachable: Bool { get }
    /// Emits a boolean every time reachability changes.
    var reachabilityChanged: Observable<Bool> { get }
}

/// Default NWPathMonitor-based implementation.
/// You can swap this with your own app-wide reachability service by writing a tiny adapter.
public final class NWPathReachability: SensorSampleUploadManagerReachability {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sensorkit.reachability.queue")
    private let subject = BehaviorSubject<Bool>(value: false)

    public private(set) var isReachable: Bool = false

    public var reachabilityChanged: Observable<Bool> { subject.asObservable() }

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let reachable = (path.status == .satisfied)
            self.isReachable = reachable
            self.subject.onNext(reachable)
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
