//
//  ReachabilityService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import RxSwift

enum ReachabilityServiceType { case wifi, cellular, none }

protocol ReachabilityService {
    
    // Needed to check initial state
    var isCurrentlyReachable: Bool { get }
    var currentReachabilityType: ReachabilityServiceType { get }
    
    func getReachability() -> Observable<ReachabilityServiceType>
}
