//
//  NineHoleTask.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 07/04/21.
//

import Foundation
import ResearchKit

class NineHoleTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, orkTaskOptions: ORKPredefinedTaskOption) -> ORKTask {
        return ORKOrderedTask.holePegTest(withIdentifier: identifier,
                                          intendedUseDescription: options?.intendedUseDescription,
                                          dominantHand: options?.dominantHand ?? .right,
                                          numberOfPegs: options?.numberOfPegs ?? 2,
                                          threshold: options?.thresholdArea ?? 0.2,
                                          rotated: false,
                                          timeLimit: options?.timeLimit ?? 300,
                                          options: orkTaskOptions)
    }
    
    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        
        let pegTestDominantPlace = ORKHolePegTestDominantPlaceStepIdentifier
        let pegTestDominantRemove = ORKHolePegTestDominantRemoveStepIdentifier
        let pegTestNonDominantPlace = ORKHolePegTestNonDominantPlaceStepIdentifier
        let pegTestNonDominantRemove = ORKHolePegTestNonDominantRemoveStepIdentifier
        
        var resultData: [String: Any] = [:]
        var stepData: [String: Any] = [:]
        
        var startDate: Date = taskResult.startDate
        var endDate: Date = taskResult.endDate
        
        let addStep: ((String, TaskNetworkParameter) -> Void) = { (stepIdentifier, networkParameter) in
            if let resultStep: ORKHolePegTestResult = taskResult.getResult(forIdentifier: stepIdentifier)?.first {
                var resultStepData: [String: Any] = [:]
                var samples: [[String: Any]] = []
                resultStepData[TaskNetworkParameter.startTime.rawValue] = resultStep.startDate.timeIntervalSince1970
                resultStepData[TaskNetworkParameter.endTime.rawValue] = resultStep.endDate.timeIntervalSince1970
                resultStepData[TaskNetworkParameter.movingDirection.rawValue] = resultStep.movingDirection.rawValue
                resultStepData[TaskNetworkParameter.dominantHand.rawValue] = resultStep.isDominantHandTested
                resultStepData[TaskNetworkParameter.numberOfPegs.rawValue] = resultStep.numberOfPegs
                resultStepData[TaskNetworkParameter.numberOfErrors.rawValue] = resultStep.totalFailures
                resultStepData[TaskNetworkParameter.threshold.rawValue] = resultStep.threshold
                resultStepData[TaskNetworkParameter.rotated.rawValue] = resultStep.isRotated
                resultStepData[TaskNetworkParameter.totalSuccesses.rawValue] = resultStep.totalSuccesses
                resultStepData[TaskNetworkParameter.totalTime.rawValue] = resultStep.totalTime
                resultStepData[TaskNetworkParameter.totalDistance.rawValue] = resultStep.totalDistance
                resultStep.samples?.forEach({ (sample) in
                    if let sample = sample as? ORKHolePegTestSample {
                        var sampleData: [String: Any] = [:]
                        sampleData[TaskNetworkParameter.time.rawValue] = sample.time
                        sampleData[TaskNetworkParameter.distance.rawValue] = sample.distance
                        samples.append(sampleData)
                    }
                })
                resultStepData[TaskNetworkParameter.samples.rawValue] = samples
                
                stepData[networkParameter.rawValue] = resultStepData
            }
        }
        
        let pegIdentifiers: [String: TaskNetworkParameter] = [pegTestDominantPlace: .holePegDominantPlace,
                                                              pegTestDominantRemove: .holePegDominantRemove,
                                                              pegTestNonDominantPlace: .holePegNonDominantPlace,
                                                              pegTestNonDominantRemove: .holePegNonDominantRemove]
        pegIdentifiers.forEach { (pegIdentifier, networkParameter) in
            addStep(pegIdentifier, networkParameter)
        }
        
        resultData[TaskNetworkParameter.holePegTask.rawValue] = stepData
        resultData[TaskNetworkParameter.startTime.rawValue] = startDate.timeIntervalSince1970
        resultData[TaskNetworkParameter.endTime.rawValue] = endDate.timeIntervalSince1970
        
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}
