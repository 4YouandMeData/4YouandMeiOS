//
//  GaitTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

class GaitTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask {
        return ORKOrderedTask.shortWalk(withIdentifier: identifier,
                                        intendedUseDescription: options?.intendedUseDescription,
                                        numberOfStepsPerLeg: options?.numberOfStepsPerLeg ?? 20,
                                        restDuration: options?.restDuration ?? 20.0,
                                        options: [])
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        // TODO: return Gait network data
        return nil
    }
}
