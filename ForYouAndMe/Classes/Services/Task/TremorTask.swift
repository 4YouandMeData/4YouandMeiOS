//
//  TremorTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

class TremorTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask {
        
        return ORKOrderedTask.tremorTest(withIdentifier: identifier,
                                         intendedUseDescription: options?.intendedUseDescription,
                                         activeStepDuration: options?.activeStepDuration ?? 10.0,
                                         activeTaskOptions: options?.tramorTaskOptions?.internalValues ?? [],
                                         handOptions: options?.handOptions?.internalValues ?? [.both],
                                         options: [])
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        // TODO: return Tremor network data
        return nil
    }
}
