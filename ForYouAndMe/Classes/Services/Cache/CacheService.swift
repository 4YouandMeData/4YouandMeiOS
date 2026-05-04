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
    var feedbackList: [String: [EmojiItem]] {get set}

    // FUAM-3021. Per-section skip-state for opt-in permission branches that
    // the user explicitly chose to skip after the watchdog tripped. Survives
    // app backgrounding so re-entry to the opt-in flow does not re-prompt.
    // Cleared on opt-in section completion.
    var skippedOptInPermissions: Set<String> { get set }
    func clearSkippedOptInPermissions()

    #if DEBUG
    func resetHealthKitCache()
    #endif
}
