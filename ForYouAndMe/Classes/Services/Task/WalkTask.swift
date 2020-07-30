//
//  WalkTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

class WalkTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask {
        return ORKOrderedTask.timedWalk(withIdentifier: identifier,
                                        intendedUseDescription: options?.intendedUseDescription,
                                        distanceInMeters: options?.distanceInMeters ?? 100.0,
                                        timeLimit: options?.timeLimit ?? 180.0,
                                        turnAroundTimeLimit: options?.turnAroundTimeLimit ?? 60.0,
                                        includeAssistiveDeviceForm: options?.includeAssistiveDeviceForm ?? true,
                                        options: [])
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        // TODO: return Walk network data
        return nil
    }
}
