//
//  TrailMakingTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

class TrailMakingTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask {
        return ORKOrderedTask.trailmakingTask(withIdentifier: identifier,
                                              intendedUseDescription: options?.intendedUseDescription,
                                              trailmakingInstruction: options?.trailmakingInstruction,
                                              trailType: options?.trailType?.internalValue ?? ORKTrailMakingTypeIdentifier.A,
                                              options: [])
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        // TODO: return Trail Making network data
        return nil
    }
}
