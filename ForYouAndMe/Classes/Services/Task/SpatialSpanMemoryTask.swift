//
//  SpatialSpanMemoryTask.swift
//  ForYouAndMe
//
//  Created on 01/07/2026.
//

import Foundation
import ResearchKit

class SpatialSpanMemoryTask {
    static func createTask(withIdentifier identifier: String, options: TaskOptions?, orkTaskOptions: ORKPredefinedTaskOption) -> ORKTask {
        return ORKOrderedTask.spatialSpanMemoryTask(withIdentifier: identifier,
                                                    intendedUseDescription: options?.intendedUseDescription,
                                                    initialSpan: 3,
                                                    minimumSpan: 2,
                                                    maximumSpan: 15,
                                                    playSpeed: 1.0,
                                                    maximumTests: 5,
                                                    maximumConsecutiveFailures: 3,
                                                    customTargetImage: nil,
                                                    customTargetPluralName: nil,
                                                    requireReversal: false,
                                                    options: orkTaskOptions)
    }

    static func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        let spatialSpanIdentifier = ORKSpatialSpanMemoryStepIdentifier
        guard let spatialSpanResult: ORKSpatialSpanMemoryResult = taskResult.getResult(forIdentifier: spatialSpanIdentifier)?.first else {
            assertionFailure("Couldn't find expected result data")
            return nil
        }

        var resultData: [String: Any] = [:]
        var gameRecords: [[String: Any]] = []

        for record in spatialSpanResult.gameRecords ?? [] {
            var touchSamples: [[String: Any]] = []
            for sample in record.touchSamples ?? [] {
                let sampleInfo: [String: Any] = [
                    TaskNetworkParameter.timestamp.rawValue: sample.timestamp,
                    TaskNetworkParameter.targetIndex.rawValue: sample.targetIndex,
                    TaskNetworkParameter.location.rawValue: ["x": sample.location.x, "y": sample.location.y],
                    TaskNetworkParameter.correct.rawValue: sample.isCorrect
                ]
                touchSamples.append(sampleInfo)
            }
            let recordInfo: [String: Any] = [
                TaskNetworkParameter.sequence.rawValue: record.sequence?.map { $0.intValue } ?? [],
                TaskNetworkParameter.gameSize.rawValue: record.gameSize,
                TaskNetworkParameter.gameStatus.rawValue: record.gameStatus.stringValue,
                TaskNetworkParameter.score.rawValue: record.score,
                TaskNetworkParameter.touchSamples.rawValue: touchSamples
            ]
            gameRecords.append(recordInfo)
        }

        resultData[TaskNetworkParameter.score.rawValue] = spatialSpanResult.score
        resultData[TaskNetworkParameter.numberOfGames.rawValue] = spatialSpanResult.numberOfGames
        resultData[TaskNetworkParameter.numberOfFailures.rawValue] = spatialSpanResult.numberOfFailures
        resultData[TaskNetworkParameter.gameRecords.rawValue] = gameRecords
        resultData[TaskNetworkParameter.startTime.rawValue] = taskResult.startDate.timeIntervalSince1970
        resultData[TaskNetworkParameter.endTime.rawValue] = taskResult.endDate.timeIntervalSince1970
        return TaskNetworkResult(data: resultData, attachedFile: nil)
    }
}

private extension ORKSpatialSpanMemoryGameStatus {
    var stringValue: String {
        switch self {
        case .success: return "success"
        case .failure: return "failure"
        case .timeout: return "timeout"
        default: return "unknown"
        }
    }
}
