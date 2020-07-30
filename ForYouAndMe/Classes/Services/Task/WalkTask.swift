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
        let trial1StepIdentifier = "timed.walk.trial1"
        let turnAroundStepIdentifier = "timed.walk.turn.around"
        let trial2StepIdentifier = "timed.walk.trial2"
        
        // TODO: Add Assistive Device Form Result when provided
        
        guard let trial1StepResultInfo: ORKTimedWalkResult = taskResult.getResult(forIdentifier: trial1StepIdentifier)?.first else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        guard let trial1StepResultFiles: [ORKFileResult] = taskResult.getResult(forIdentifier: trial1StepIdentifier) else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        
        let turnAroundStepResultInfo: ORKTimedWalkResult? = taskResult.getResult(forIdentifier: turnAroundStepIdentifier)?.first
        let turnAroundStepResultFiles: [ORKFileResult]? = taskResult.getResult(forIdentifier: turnAroundStepIdentifier)
        
        guard let trial2StepResultInfo: ORKTimedWalkResult = taskResult.getResult(forIdentifier: trial2StepIdentifier)?.first else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        guard let trial2StepResultFiles: [ORKFileResult] = taskResult.getResult(forIdentifier: trial2StepIdentifier) else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }
        
        var resultData: [String: Any] = [:]
        
        // Trial 1
        var trial1StepResultData: [String: Any] = [
            TaskNetworkParameter.distanceInMeters.rawValue: trial1StepResultInfo.distanceInMeters,
            TaskNetworkParameter.timeLimit.rawValue: trial1StepResultInfo.timeLimit,
            TaskNetworkParameter.duration.rawValue: trial1StepResultInfo.duration
        ]
        trial1StepResultFiles.fileResults.forEach { trial1StepResultData[$0] = $1 }
        resultData[TaskNetworkParameter.timedWalkTrial1.rawValue] = trial1StepResultData
        
        // Turn Around
        if let turnAroundStepResultInfo = turnAroundStepResultInfo {
            var turnAroundStepResultData: [String: Any] = [
                TaskNetworkParameter.distanceInMeters.rawValue: turnAroundStepResultInfo.distanceInMeters,
                TaskNetworkParameter.timeLimit.rawValue: turnAroundStepResultInfo.timeLimit,
                TaskNetworkParameter.duration.rawValue: turnAroundStepResultInfo.duration
            ]
            if let turnAroundStepResultFiles = turnAroundStepResultFiles {
                turnAroundStepResultFiles.fileResults.forEach { turnAroundStepResultData[$0] = $1 }
                resultData[TaskNetworkParameter.timedWalkTurnAround.rawValue] = turnAroundStepResultData
            }
        }
        
        // Trial 2
        var trial2StepResultData: [String: Any] = [
            TaskNetworkParameter.distanceInMeters.rawValue: trial2StepResultInfo.distanceInMeters,
            TaskNetworkParameter.timeLimit.rawValue: trial2StepResultInfo.timeLimit,
            TaskNetworkParameter.duration.rawValue: trial2StepResultInfo.duration
        ]
        trial2StepResultFiles.fileResults.forEach { trial2StepResultData[$0] = $1 }
        resultData[TaskNetworkParameter.timedWalkTrial2.rawValue] = trial2StepResultData
        
        resultData[TaskNetworkParameter.startTime.rawValue] = trial1StepResultInfo.startDate.timeIntervalSince1970
        resultData[TaskNetworkParameter.endTime.rawValue] = trial2StepResultInfo.endDate.timeIntervalSince1970
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}