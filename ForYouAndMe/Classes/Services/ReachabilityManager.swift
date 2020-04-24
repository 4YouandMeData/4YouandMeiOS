//
//  ReachabilityManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Reachability
import RxSwift

class ReachabilityManager: ReachabilityService {
    
    private var reachability: Reachability?
    
    private let reachabilitySubject: BehaviorSubject<Reachability.Connection>
    private final let disposeBag = DisposeBag()
    
    // MARK: - Service Protocol Implementation
    
    public init() {
        try? self.reachability = Reachability()
        self.reachabilitySubject = BehaviorSubject<Reachability.Connection>(value: self.reachability?.connection ?? .unavailable)
        try? self.reachability?.startNotifier()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reachabilityChanged(note:)),
                                               name: .reachabilityChanged,
                                               object: self.reachability)
    }
    
    // MARK: - NetworkService Protocol Implementation
    
    public var isCurrentlyReachable: Bool {
        if let reachability = reachability {
            return reachability.connection != .unavailable
        } else {
            return true
        }
    }
    
    public func getReachability() -> Observable<ReachabilityServiceType> {
        return self.reachabilitySubject.map { $0.reachabilityServiceType }
    }
    
    // MARK: - Actions
    
    @objc private  func reachabilityChanged(note: Notification) {
        
        if let reachability = note.object as? Reachability {
            self.reachabilitySubject.onNext(reachability.connection)
            switch reachability.connection {
            case .wifi:
                print("Reachable via WiFi")
            case .cellular:
                print("Reachable via Cellular")
            case .unavailable, .none:
                print("Network not reachable")
            }
        } else {
            assertionFailure("Unexpected Object type")
        }
    }
}

extension Reachability.Connection {
    var reachabilityServiceType: ReachabilityServiceType {
        switch self {
        case .cellular: return .cellular
        case .wifi: return .wifi
        case .unavailable, .none: return .none
        }
    }
}
