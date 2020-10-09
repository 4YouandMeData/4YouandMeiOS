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
    case reactionTime = "reaction_time_task"
    case trailMaking = "trail_making_task"
    case walk = "timed_walk_task"
    case gait = "gait_task"
    case tremor = "tremor_task"
    case fitness = "walk_task"
    case videoDiary = "video_diary"
    case camcogPvt = "camcog_pvt"
    case camcogNbx = "camcog_nbx"
    case camcogEbt = "camcog_ebt"
}

extension TaskType {
    
    func createTask(withIdentifier identifier: String, options: TaskOptions?, locationAuthorised: Bool) -> ORKTask? {
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
        case .fitness:
            return FitnessTask.createTask(withIdentifier: identifier, options: options, locationAuthorised: locationAuthorised)
        case .videoDiary, .camcogPvt, .camcogNbx, .camcogEbt:
            return nil
        }
    }
    
    func getNetworkResultData(taskResult: ORKTaskResult) -> TaskNetworkResult? {
        switch self {
        case .reactionTime: return ReactionTimeTask.getNetworkResultData(taskResult: taskResult)
        case .trailMaking: return TrailMakingTask.getNetworkResultData(taskResult: taskResult)
        case .walk: return WalkTask.getNetworkResultData(taskResult: taskResult)
        case .gait: return GaitTask.getNetworkResultData(taskResult: taskResult)
        case .tremor: return TremorTask.getNetworkResultData(taskResult: taskResult)
        case .fitness: return FitnessTask.getNetworkResultData(taskResult: taskResult)
        case .videoDiary, .camcogEbt, .camcogNbx, .camcogPvt: return nil
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
    case heartRate
}

// MARK: - TaskNetworkParameter

enum TaskNetworkParameter: String {
    case taskId = "task_id"
    case timestamp
    case id
    case numberOfErrors
    case attempts
    case deviceMotionInfo = "device_motion_info"
    case accelerometerInfo = "accelerometer_info"
    case locationInfo = "location_info"
    case pedometerInfo = "pedometer_info"
    case heartRate = "heart_rate"
    case startTime = "start_time"
    case endTime = "end_time"
    case startDate = "start_date"
    case endDate = "end_date"
    case index
    case incorrect
    case taps
    case timedWalkTrial1 = "timed_walk_trial_1"
    case timedWalkTurnAround = "timed_walk_turn_around"
    case timedWalkTrial2 = "timed_walk_trial_2"
    case distanceInMeters = "distance_in_meters"
    case timeLimit = "time_limit"
    case duration = "duration"
    case timedWalkFormAfo = "timed_walk_form_afo"
    case timedWalkFormAssistance = "timed_walk_form_assistance"
    case gaitOutbound = "gait_outbound"
    case gaitReturn = "gait_return"
    case gaitRest = "gait_rest"
    case tremorHandSkip = "tremor_hand_skip"
    case tremorHandInLap = "tremor_hand_in_lap"
    case tremorHandExtendArm = "tremor_hand_extern_arm"
    case tremorHandBendArm = "tremor_hand_bend_arm"
    case tremorHandTouchNose = "tremor_hand_touch_nose"
    case tremorHandTurnWrist = "tremor_hand_turn_wrist"
    case fitnessWalk = "fitness_walk"
    case fitnessRest = "fitness_rest"
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
    
    // Fitness
    let walkDuration: Double?
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

extension ORKTaskResult {
    func getResult<T: ORKResult>(forIdentifier identifier: String) -> [T]? {
        guard let result = ((self.results?
            .filter({ $0.identifier == identifier })
            .first as? ORKStepResult)?
            .results?
            .filter({ $0 is T }) as? [T]) else {
            return nil
        }
        return result
    }
}

extension Array where Element == ORKFileResult {
    var fileResults: [String: Any] {
        var result: [String: Any] = [:]
        
        for fileResult in self {
            guard fileResult.contentType == Constants.Task.fileResultMimeType,
                let url = fileResult.fileURL,
                let value = try? String(contentsOf: url, encoding: .utf8) else {
                    return result
            }

            switch fileResult.identifier {
            case TaskRecorderIdentifier.deviceMotion.rawValue:
                result[TaskNetworkParameter.deviceMotionInfo.rawValue] = value
            case TaskRecorderIdentifier.accelerometer.rawValue:
                result[TaskNetworkParameter.accelerometerInfo.rawValue] = value
            case TaskRecorderIdentifier.pedometer.rawValue:
                result[TaskNetworkParameter.pedometerInfo.rawValue] = value
            case TaskRecorderIdentifier.location.rawValue:
                result[TaskNetworkParameter.locationInfo.rawValue] = value
            case TaskRecorderIdentifier.heartRate.rawValue:
                result[TaskNetworkParameter.heartRate.rawValue] = value
            default:
                break
            }
        }
        return result
    }
}
