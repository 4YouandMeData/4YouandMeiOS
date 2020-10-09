//
//  TrailMakingTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

class TrailMakingTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, orkTaskOptions: ORKPredefinedTaskOption) -> ORKTask {
        return ORKOrderedTask.trailmakingTask(withIdentifier: identifier,
                                              intendedUseDescription: options?.intendedUseDescription,
                                              trailmakingInstruction: options?.trailmakingInstruction,
                                              trailType: options?.trailType?.internalValue ?? ORKTrailMakingTypeIdentifier.A,
                                              options: orkTaskOptions)
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        let trailMakingIdentifier = ORKTrailmakingStepIdentifier
        guard let trailMakingResult: ORKTrailmakingResult = taskResult.getResult(forIdentifier: trailMakingIdentifier)?.first else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        
        var resultData: [String: Any] = [:]
        var taps: [[String: Any]] = []
        
        for tap in trailMakingResult.taps {
            let tapInfo: [String: Any] = [TaskNetworkParameter.timestamp.rawValue: tap.timestamp,
                                          TaskNetworkParameter.index.rawValue: tap.index,
                                          TaskNetworkParameter.incorrect.rawValue: tap.incorrect]
            taps.append(tapInfo)
        }
        resultData[TaskNetworkParameter.taps.rawValue] = taps
        resultData[TaskNetworkParameter.numberOfErrors.rawValue] = trailMakingResult.numberOfErrors
        resultData[TaskNetworkParameter.startTime.rawValue] = trailMakingResult.startDate.timeIntervalSince1970
        resultData[TaskNetworkParameter.endTime.rawValue] = trailMakingResult.endDate.timeIntervalSince1970
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}
