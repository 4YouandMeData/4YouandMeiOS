//
//  HealthDataType.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/21.
//

import Foundation

public enum HealthDataType: String, CaseIterable {
    // Activity
    case stepCount
    case distanceWalkingRunning
    case distanceCycling
    case pushCount
    case distanceWheelChair
    case swimmingStrokeCount
    case distanceSwimming
    case distanceDownhillSnowSports
    case basalEnergyBurned
    case activeEnergyBurned
    case flightsClimbed
    case nikeFuel
    case appleExerciseTime
    case appleStandHour
    case appleStandTime
    case vo2Max
    case lowCardioFitnessEvent
    // Charasteristics
    case activityMoveMode
    case biologicalSex
    case bloodType
    case dateOfBirth
    case fitzpatrickSkinType
    case wheelchairUse
    // Vital Signs
    case heartRate
    case lowHeartRateEvent
    case highHeartRateEvent
    case irregularHeartRhythmEvent
    case restingHeartRate
    case heartRateVariabilitySDNN
    case walkingHeartRateAverage
    // TODO: Understance usage
//    case HKDataTypeIdentifierHeartbeatSeries
    case electrocardiogram
    case oxygenSaturation
    case bodyTemperature
    case bloodPressure
    case bloodPressureSystolic
    case bloodPressureDiastolic
    case respiratoryRate
    // Mindfulness and Sleep
    case mindfulSession
    case sleepAnalysis
    // Workouts
    // TODO: Understance usage
//    case utTypeIdentifier
    // TODO: Understance usage
//    case utRouteTypeIdentifier
}

#if HEALTHKIT
import HealthKit

extension Array where Element == HealthDataType {
    var objectTypeSet: Set<HKObjectType> { self.compactMap { $0.objectType }.toSet }
}

extension HealthDataType {
    var keyName: String? {
        return self.rawValue
    }
    
    var objectType: HKObjectType? {
        switch self {
        // Activity
        case .stepCount: return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .distanceWalkingRunning: return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .distanceCycling: return HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case .pushCount: return HKObjectType.quantityType(forIdentifier: .pushCount)
        case .distanceWheelChair: return HKObjectType.quantityType(forIdentifier: .distanceWheelchair)
        case .swimmingStrokeCount: return HKObjectType.quantityType(forIdentifier: .swimmingStrokeCount)
        case .distanceSwimming: return HKObjectType.quantityType(forIdentifier: .distanceSwimming)
        case .distanceDownhillSnowSports: return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)
        case .basalEnergyBurned: return HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)
        case .activeEnergyBurned: return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case .flightsClimbed: return HKObjectType.quantityType(forIdentifier: .flightsClimbed)
        case .nikeFuel: return HKObjectType.quantityType(forIdentifier: .nikeFuel)
        case .appleExerciseTime: return HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        case .appleStandHour: return HKObjectType.categoryType(forIdentifier: .appleStandHour)
        case .appleStandTime: return HKObjectType.quantityType(forIdentifier: .appleStandTime)
        case .vo2Max: return HKObjectType.quantityType(forIdentifier: .vo2Max)
        case .lowCardioFitnessEvent:
            if #available(iOS 14.3, *) {
                return HKObjectType.categoryType(forIdentifier: .lowCardioFitnessEvent)
            } else {
                return nil
            }
        // Charasteristics
        case .activityMoveMode:
            if #available(iOS 14.0, *) {
            return HKObjectType.characteristicType(forIdentifier: .activityMoveMode)
            } else {
                return nil
            }
        case .biologicalSex: return HKObjectType.characteristicType(forIdentifier: .biologicalSex)
        case .bloodType: return HKObjectType.characteristicType(forIdentifier: .bloodType)
        case .dateOfBirth: return HKObjectType.characteristicType(forIdentifier: .dateOfBirth)
        case .fitzpatrickSkinType: return HKObjectType.characteristicType(forIdentifier: .fitzpatrickSkinType)
        case .wheelchairUse: return HKObjectType.characteristicType(forIdentifier: .wheelchairUse)
        // Vital Signs
        case .heartRate: return HKObjectType.quantityType(forIdentifier: .heartRate)
        case .lowHeartRateEvent: return HKObjectType.categoryType(forIdentifier: .lowHeartRateEvent)
        case .highHeartRateEvent: return HKObjectType.categoryType(forIdentifier: .highHeartRateEvent)
        case .irregularHeartRhythmEvent: return HKObjectType.categoryType(forIdentifier: .irregularHeartRhythmEvent)
        case .restingHeartRate: return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .heartRateVariabilitySDNN: return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .walkingHeartRateAverage: return HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .electrocardiogram:
            if #available(iOS 14.0, *) {
                return HKObjectType.electrocardiogramType()
            } else {
                return nil
            }
        case .oxygenSaturation: return HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
        case .bodyTemperature: return HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        case .bloodPressureSystolic: return HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .bloodPressureDiastolic: return HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .bloodPressure: return nil // No need to ask permission for correlation types
        case .respiratoryRate: return HKObjectType.quantityType(forIdentifier: .respiratoryRate)
        // Mindfulness and Sleep
        case .mindfulSession: return HKObjectType.categoryType(forIdentifier: .mindfulSession)
        case .sleepAnalysis: return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        // Workouts
        }
    }
    
    var sampleType: HKSampleType? {
        return self.objectType as? HKSampleType
    }
}

extension Date {
    var healthDateString: String {
        return self.string(withFormat: "yyyy-MM-dd")
    }
}

#endif
