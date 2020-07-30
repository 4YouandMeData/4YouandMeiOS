//
//  ReactionTimeTask.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

class ReactionTimeTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask {
        return ORKOrderedTask.reactionTime(withIdentifier: identifier,
                                           intendedUseDescription: options?.intendedUseDescription,
                                           maximumStimulusInterval: options?.maximumStimulusInterval ?? 10,
                                           minimumStimulusInterval: options?.minimumStimulusInterval ?? 4,
                                           thresholdAcceleration: options?.thresholdAcceleration ?? 0.5,
                                           numberOfAttempts: Int32(options?.numberOfAttempts ?? 3),
                                           timeout: options?.timeOut ?? 3,
                                           successSound: UInt32(kSystemSoundID_Vibrate),
                                           timeoutSound: 0,
                                           failureSound: UInt32(kSystemSoundID_Vibrate),
                                           options: locationAuthorised ? [] : [.excludeLocation])
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        let reactionTimeIdentifier = ORKReactionTimeStepIdentifier
        guard let reactionTimeTaskResult: [ORKReactionTimeResult] = taskResult.getResult(forIdentifier: reactionTimeIdentifier) else {
                assertionFailure("Couldn't find expected result data")
                return nil
        }
        
        var resultData: [String: Any] = [:]
        var attempts: [[String: Any]] = []
        
        let reactionTimeResult = reactionTimeTaskResult.filter({ $0.identifier == reactionTimeIdentifier })
        reactionTimeResult.forEach { timeResult in
            if timeResult.fileResult.contentType == Constants.Task.fileResultMimeType, let fileURL = timeResult.fileResult.fileURL {
                var attempt: [String: Any] = [TaskNetworkParameter.timestamp.rawValue: timeResult.timestamp]
                let infoValue = try? String(contentsOf: fileURL, encoding: .utf8)
                var infoKey: String?
                if timeResult.fileResult.identifier == TaskRecorderIdentifier.deviceMotion.rawValue {
                    infoKey = TaskNetworkParameter.deviceMotionInfo.rawValue
                } else if timeResult.identifier == TaskRecorderIdentifier.accelerometer.rawValue {
                    infoKey = TaskNetworkParameter.accelerometerInfo.rawValue
                }
                
                if let infoKey = infoKey, let infoValue = infoValue {
                    attempt[infoKey] = infoValue
                }
                attempts.append(attempt)
            }
        }

        resultData[TaskNetworkParameter.attempts.rawValue] = attempts
        resultData[TaskNetworkParameter.startTime.rawValue] = reactionTimeResult.first?.startDate.timeIntervalSince1970
        resultData[TaskNetworkParameter.endTime.rawValue] = reactionTimeResult.last?.endDate.timeIntervalSince1970
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}
