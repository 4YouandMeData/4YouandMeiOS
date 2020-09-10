//
//  FitnessTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/09/2020.
//

import Foundation
import ResearchKit

class FitnessTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask {
        return ORKOrderedTask.fitnessCheck(withIdentifier: identifier,
                                           intendedUseDescription: options?.intendedUseDescription,
                                           walkDuration: options?.walkDuration ?? 60.0,
                                           restDuration: options?.restDuration ?? 10.0,
                                           options: [.excludeHeartRate])
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        guard let walkStepResultFiles: [ORKFileResult] = taskResult.getResult(forIdentifier: ORKFitnessWalkStepIdentifier) else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        
        let restStepResultFiles: [ORKFileResult]? = taskResult.getResult(forIdentifier: ORKFitnessRestStepIdentifier)
        
        var resultData: [String: Any] = [:]
        
        // Walk
        var walkStepResultData: [String: Any] = [:]
        walkStepResultFiles.fileResults.forEach { walkStepResultData[$0] = $1 }
        resultData[TaskNetworkParameter.fitnessWalk.rawValue] = walkStepResultData
        
        // Rest
        if let restStepResultFiles = restStepResultFiles {
            var restStepResultData: [String: Any] = [:]
            restStepResultFiles.fileResults.forEach { restStepResultData[$0] = $1 }
            resultData[TaskNetworkParameter.fitnessRest.rawValue] = restStepResultData
        }
        
        if let startDate = walkStepResultFiles.first?.startDate {
            resultData[TaskNetworkParameter.startTime.rawValue] = startDate.timeIntervalSince1970
        }
        if let endDate = restStepResultFiles?.first?.endDate ?? walkStepResultFiles.first?.endDate {
            resultData[TaskNetworkParameter.endTime.rawValue] = endDate.timeIntervalSince1970
        }
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}
