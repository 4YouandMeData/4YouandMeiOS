//
//  GaitTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

class GaitTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, orkTaskOptions: ORKPredefinedTaskOption) -> ORKTask {
        return ORKOrderedTask.shortWalk(withIdentifier: identifier,
                                        intendedUseDescription: options?.intendedUseDescription,
                                        numberOfStepsPerLeg: options?.numberOfStepsPerLeg ?? 20,
                                        restDuration: options?.restDuration ?? 20.0,
                                        options: orkTaskOptions)
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        let outboundStepIdentifier = ORKShortWalkOutboundStepIdentifier
        let returnStepIdentifier = ORKShortWalkReturnStepIdentifier
        let restStepIdentifier = ORKShortWalkRestStepIdentifier
        
        guard let outboundStepResultFiles: [ORKFileResult] = taskResult.getResult(forIdentifier: outboundStepIdentifier) else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        
        guard let returnStepResultFiles: [ORKFileResult] = taskResult.getResult(forIdentifier: returnStepIdentifier) else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        
        let restStepResultFiles: [ORKFileResult]? = taskResult.getResult(forIdentifier: restStepIdentifier)
        
        var resultData: [String: Any] = [:]
        
        // Outbound
        var outboundStepResultData: [String: Any] = [:]
        outboundStepResultFiles.fileResults.forEach { outboundStepResultData[$0] = $1 }
        resultData[TaskNetworkParameter.gaitOutbound.rawValue] = outboundStepResultData
        
        // Return
        var returnStepResultData: [String: Any] = [:]
        returnStepResultFiles.fileResults.forEach { returnStepResultData[$0] = $1 }
        resultData[TaskNetworkParameter.gaitReturn.rawValue] = returnStepResultData
        
        // Rest
        if let restStepResultFiles = restStepResultFiles {
            var restStepResultData: [String: Any] = [:]
            restStepResultFiles.fileResults.forEach { restStepResultData[$0] = $1 }
            resultData[TaskNetworkParameter.gaitRest.rawValue] = restStepResultData
        }
        
        if let startDate = outboundStepResultFiles.first?.startDate {
            resultData[TaskNetworkParameter.startTime.rawValue] = startDate.timeIntervalSince1970
        }
        if let endDate = restStepResultFiles?.first?.endDate ?? returnStepResultFiles.first?.endDate {
            resultData[TaskNetworkParameter.endTime.rawValue] = endDate.timeIntervalSince1970
        }
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}
