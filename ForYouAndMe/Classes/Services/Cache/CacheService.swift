//
//  CacheService.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 26/09/2020.
//

import Foundation

protocol CacheService {
    
    var user: User? { get set }
    var deviceUDID: String? { get set }
    var firstUserAbsoluteLocation: UserLocation? { get set }
    var excludedUserDataAggregationIds: [String]? { get set }
    var infoMessages: [MessageInfo]? { get set }
    
    #if DEBUG
    func resetHealthKitCache()
    #endif
}
