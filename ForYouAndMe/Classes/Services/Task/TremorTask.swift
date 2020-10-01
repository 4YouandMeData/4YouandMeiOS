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
        let leftHandIdentifier = ORKActiveTaskLeftHandIdentifier
        let mostAffectedHandIdentifier = ORKActiveTaskMostAffectedHandIdentifier
        let rightHandIdentifier = ORKActiveTaskRightHandIdentifier
        
        let skipHandIdentifier = ORKActiveTaskSkipHandStepIdentifier
        
        let inLapStepIdentifier = ORKTremorTestInLapStepIdentifier
        let extendArmStepIdentifier = ORKTremorTestExtendArmStepIdentifier
        let bendArmStepIdentifier = ORKTremorTestBendArmStepIdentifier
        let touchNoseStepIdentifier = ORKTremorTestTouchNoseStepIdentifier
        let turnWristStepIdentifier = ORKTremorTestTurnWristStepIdentifier
        
        let skipHandAnswerResultInfo: ORKChoiceQuestionResult? = taskResult.getResult(forIdentifier: skipHandIdentifier)?.first

        var startDate: Date = taskResult.startDate
        var endDate: Date = taskResult.endDate
        
        var resultData: [String: Any] = [:]
        
        if let skipHandAnswerResultInfo = skipHandAnswerResultInfo, let answers = skipHandAnswerResultInfo.choiceAnswers {
            resultData[TaskNetworkParameter.tremorHandSkip.rawValue] = answers
        }
        
        let addFiles: ((String, String, TaskNetworkParameter) -> Void) = { (stepIdentifier, handIdentifier, networkParameter) in
            let identifier = String.createHandStepIdentifier(forStepIdentifier: stepIdentifier, handIdentifier: handIdentifier)
            if let resultFiles: [ORKFileResult] = taskResult.getResult(forIdentifier: identifier) {
                var resultStepData: [String: Any] = [:]
                resultFiles.fileResults.forEach { resultStepData[$0] = $1 }
                resultData[networkParameter.getNetworkParameterValue(forHandIdentifier: handIdentifier)] = resultStepData
                if let newStartDate = resultFiles.first?.startDate, newStartDate < startDate {
                    startDate = newStartDate
                }
                if let newEndDate = resultFiles.first?.endDate, newEndDate > endDate {
                    endDate = newEndDate
                }
            }
        }
        
        let handIdentifiers: [String] = [leftHandIdentifier, mostAffectedHandIdentifier, rightHandIdentifier]
        handIdentifiers.forEach { handIdentifier in
            addFiles(inLapStepIdentifier, handIdentifier, .tremorHandInLap)
            addFiles(extendArmStepIdentifier, handIdentifier, .tremorHandExtendArm)
            addFiles(bendArmStepIdentifier, handIdentifier, .tremorHandBendArm)
            addFiles(touchNoseStepIdentifier, handIdentifier, .tremorHandTouchNose)
            addFiles(turnWristStepIdentifier, handIdentifier, .tremorHandTurnWrist)
        }
        
        resultData[TaskNetworkParameter.startTime.rawValue] = startDate.timeIntervalSince1970
        resultData[TaskNetworkParameter.endTime.rawValue] = endDate.timeIntervalSince1970
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}

fileprivate extension String {
    static func createHandStepIdentifier(forStepIdentifier stepIdentifier: String, handIdentifier: String) -> String {
        // TODO: Get this static method from Research Kit
        return stepIdentifier + "." + handIdentifier
    }
}

fileprivate extension TaskNetworkParameter {
    func getNetworkParameterValue(forHandIdentifier handIdentifier: String) -> String {
        return self.rawValue + "_" + handIdentifier
    }
}
