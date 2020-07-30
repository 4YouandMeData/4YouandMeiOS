//
//  TaskType.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/07/2020.
//

import Foundation
import ResearchKit

// MARK: - TaskType

enum TaskType: String, CaseIterable {
    case reactionTime
    case trailMaking
    case walk
    case gait
    case tremor
    
    var identifier: String {
        return self.rawValue
    }
}

extension TaskType {
    
    func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask {
        switch self {
        case .reactionTime:
            return ReactionTimeTask.createTask(withIdentifier: identifier, options: options, locationAuthorised: locationAuthorised)
        case .trailMaking:
            return TrailMakingTask.createTask(withIdentifier: identifier, options: options, locationAuthorised: locationAuthorised)
        case .walk:
            return WalkTask.createTask(withIdentifier: identifier, options: options, locationAuthorised: locationAuthorised)
        case .gait:
            return GaitTask.createTask(withIdentifier: identifier, options: options, locationAuthorised: locationAuthorised)
        case .tremor:
            return TremorTask.createTask(withIdentifier: identifier, options: options, locationAuthorised: locationAuthorised)
        }
    }
    
    func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        switch self {
        case .reactionTime: return ReactionTimeTask.getNetworkResultData(taskResult: taskResult)
        case .trailMaking: return TrailMakingTask.getNetworkResultData(taskResult: taskResult)
        case .walk: return WalkTask.getNetworkResultData(taskResult: taskResult)
        case .gait: return GaitTask.getNetworkResultData(taskResult: taskResult)
        case .tremor: return TremorTask.getNetworkResultData(taskResult: taskResult)
        }
    }
}

// MARK: - TaskNetworkResult

struct TaskNetworkResult {
    let data: TaskNetworkResultData
    let attachedFile: TaskNetworkResultFile?
}

// MARK: - TaskRecorderIdentifier

enum TaskRecorderIdentifier: String {
    case deviceMotion
    case accelerometer
    case pedometer
    case location
}

// MARK: - TaskNetworkParameter

enum TaskNetworkParameter: String {
    case taskId = "task_id"
    case timestamp
    case id
    case numberOfErrors
    case attempts
    case deviceMotionInfo = "deviceMotion_info"
    case accelerometerInfo = "accelerometer_info"
    case locationInfo = "location_info"
    case pedometerInfo = "pedometer_info"
    case startTime = "start_time"
    case endTime = "end_time"
    case startDate = "start_date"
    case endDate = "end_date"
    case index
    case incorrect
    case taps
}

// MARK: - TaskOptions

struct TaskOptions {
    let intendedUseDescription: String?
    let includeAssistiveDeviceForm: Bool?
    let timeLimit: Double?
    let handOptions: [TaskHandOption]?
    
    // Reaction Time
    let maximumStimulusInterval: Double?
    let minimumStimulusInterval: Double?
    let thresholdAcceleration: Double?
    let numberOfAttempts: Int?
    let timeOut: Double?
    
    // Trail Making
    let trailmakingInstruction: String?
    let trailType: TrailType?
    
    // Walk
    let distanceInMeters: Double?
    let turnAroundTimeLimit: Double?
    
    // Gait
    let numberOfStepsPerLeg: Int?
    let restDuration: Double?
    
    // Tremor
    let activeStepDuration: Double?
    let tramorTaskOptions: [TaskTremorOption]?
}

// MARK: - TrailType

enum TrailType: String {
    case versionA
    case versionB
}

extension TrailType {
    var internalValue: ORKTrailMakingTypeIdentifier {
        switch self {
        case .versionA: return ORKTrailMakingTypeIdentifier.A
        case .versionB: return ORKTrailMakingTypeIdentifier.B
        }
    }
}

// MARK: - TaskTremorOption

enum TaskTremorOption: String {
    case excludeHandInLap
    case excludeHandAtShoulderHeight
    case excludeHandAtShoulderHeightElbowBent
    case excludeHandToNose
    case excludeQueenWave
}

extension TaskTremorOption {
    var internalValue: ORKTremorActiveTaskOption {
        switch self {
        case .excludeHandInLap: return ORKTremorActiveTaskOption.excludeHandInLap
        case .excludeHandAtShoulderHeight: return ORKTremorActiveTaskOption.excludeHandAtShoulderHeight
        case .excludeHandAtShoulderHeightElbowBent: return ORKTremorActiveTaskOption.excludeHandAtShoulderHeightElbowBent
        case .excludeHandToNose: return ORKTremorActiveTaskOption.excludeHandToNose
        case .excludeQueenWave: return ORKTremorActiveTaskOption.excludeQueenWave
        }
    }
}

extension Array where Element == TaskTremorOption {
    var internalValues: ORKTremorActiveTaskOption {
        return self.reduce([]) { (result, option) in
            var result = result
            result.insert(option.internalValue)
            return result
        }
    }
}

// MARK: - TaskHandOption

enum TaskHandOption: String {
    case left
    case right
    case both
}

extension TaskHandOption {
    var internalValue: ORKPredefinedTaskHandOption {
        switch self {
        case .left: return ORKPredefinedTaskHandOption.left
        case .right: return ORKPredefinedTaskHandOption.right
        case .both: return ORKPredefinedTaskHandOption.both
        }
    }
}

extension Array where Element == TaskHandOption {
    var internalValues: ORKPredefinedTaskHandOption {
        return self.reduce([]) { (result, option) in
            var result = result
            result.insert(option.internalValue)
            return result
        }
    }
}
