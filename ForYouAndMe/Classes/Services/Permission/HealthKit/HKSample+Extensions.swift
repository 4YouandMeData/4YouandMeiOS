//
//  HKSample+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/21.
//

import Foundation

#if HEALTHKIT
import HealthKit

// MARK: - HealthDataType Validation

extension HealthDataType {
    
    var isValid: Bool {
        return self.isUnitValid
    }
}

// MARK: - HKSample

extension Array where Element == HKSample {
    func getNetworkData(forDataType dataType: HealthDataType) -> HealthNetworkData {
        return [dataType.keyName: self.map { $0.getDictionary(forDataType: dataType) }]
    }
}

extension HKSample {
    func getDictionary(forDataType dataType: HealthDataType) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // HKObject
        result["uuid"] = self.uuid.uuidString
        result["sourceRevision"] = self.sourceRevision.dictionary
        if let device = self.device {
            result["device"] = device.dictionary
        }
        if let metadata = self.metadata {
            result["metadata"] = metadata
        }
        
        // HKSample
        result["isMaximumDurationRestricted"] = self.sampleType.isMaximumDurationRestricted
        result["maximumAllowedDuration"] = self.sampleType.maximumAllowedDuration
        result["isMinimumDurationRestricted"] = self.sampleType.isMinimumDurationRestricted
        result["minimumAllowedDuration"] = self.sampleType.minimumAllowedDuration
        result["startDate"] = self.startDate.sampleDateTimeString
        result["endDate"] = self.endDate.sampleDateTimeString
        
        if let quantitySample = self as? HKQuantitySample {
            // HKQuantitySample
            result["sampleClass"] = "quantity"
            if let unit = dataType.unit {
                result["quantity"] = quantitySample.quantity.getDictionary(forUnit: unit)
            } else {
                assertionFailure("Missing Unit")
                result["quantity"] = "missingUnit"
            }
            result["quantityType"] = quantitySample.quantityType.dictionary
            result["count"] = quantitySample.count
        } else if let categorySample = self as? HKCategorySample {
            // HKCategorySample
            result["sampleClass"] = "category"
            result["value"] = categorySample.value
        } else if #available(iOS 14.0, *), let electrocardiogram = self as? HKElectrocardiogram {
            // HKElectrocardiogram
            result["sampleClass"] = "electrocardiogram"
            result["numberOfVoltageMeasurements"] = electrocardiogram.numberOfVoltageMeasurements
            if let samplingFrequency = electrocardiogram.samplingFrequency {
                result["samplingFrequency"] = samplingFrequency.getDictionary(forUnit: HKUnit.hertz())
            }
            result["classification"] = electrocardiogram.classification.stringValue
            if let averageHeartRate = electrocardiogram.averageHeartRate {
                result["averageHeartRate"] = averageHeartRate.getDictionary(forUnit: HKUnit.defaultCountOnTime)
            }
            result["symptomsStatus"] = electrocardiogram.symptomsStatus.stringValue
        } else if let correlationSample = self as? HKCorrelation {
            result["sampleClass"] = "correlation"
            result["objects"] = correlationSample.objects.map { $0.getDictionary(forDataType: dataType) }
        } else if let workoutSample = self as? HKWorkout {
            result["sampleClass"] = "workout"
            result["workoutActivityType"] = workoutSample.workoutActivityType.stringValue
            if let workoutEvents = workoutSample.workoutEvents {
                result["workoutEvents"] = workoutEvents.map { $0.dictionary }
            }
            result["duration"] = workoutSample.duration
            if let totalEnergyBurned = workoutSample.totalEnergyBurned {
                result["totalEnergyBurned"] = totalEnergyBurned.getDictionary(forUnit: HKUnit.defaultEnergy)
            }
            if let totalDistance = workoutSample.totalDistance {
                result["totalDistance"] = totalDistance.getDictionary(forUnit: HKUnit.defaultShortDistance)
            }
            if let totalSwimmingStrokeCount = workoutSample.totalSwimmingStrokeCount {
                result["totalSwimmingStrokeCount"] = totalSwimmingStrokeCount.getDictionary(forUnit: HKUnit.defaultCount)
            }
            if let totalFlightsClimbed = workoutSample.totalFlightsClimbed {
                result["totalFlightsClimbed"] = totalFlightsClimbed.getDictionary(forUnit: HKUnit.defaultCountOnTime)
            }
        } else if let heartBeatSeriesSample = self as? HKHeartbeatSeriesSample {
            result["sampleClass"] = "heartBeatSeries"
            result["count"] = heartBeatSeriesSample.count
        } else if let workoutRouteSample = self as? HKWorkoutRoute {
            result["sampleClass"] = "workoutRoute"
            result["count"] = workoutRouteSample.count
        } else {
            assertionFailure("Unhandled subclass")
            result["sampleClass"] = "unhandled"
        }
        
        return result
    }
}

// MARK: - HKObject

extension HKSourceRevision {
    var dictionary: [String: Any] {
        var result: [String: Any] = [:]
        
        if let productType = self.productType {
            result["productType"] = productType
        }
        if let version = self.version {
            result["version"] = version
        }
        result["operatingSystemVersion"] = self.operatingSystemVersion.stringValue
        result["source"] = self.source.dictionary
        return result
    }
}

extension HKSource {
    var dictionary: [String: Any] {
        var result: [String: Any] = [:]
        result["name"] = self.name
        result["bundleIdentifier"] = self.bundleIdentifier
        return result
    }
}

extension HKDevice {
    var dictionary: [String: Any] {
        var result: [String: Any] = [:]
        if let name = self.name {
            result["name"] = name
        }
        if let manufacturer = self.manufacturer {
            result["manufacturer"] = manufacturer
        }
        if let model = self.model {
            result["model"] = model
        }
        if let hardwareVersion = self.hardwareVersion {
            result["hardwareVersion"] = hardwareVersion
        }
        if let firmwareVersion = self.firmwareVersion {
            result["firmwareVersion"] = firmwareVersion
        }
        if let softwareVersion = self.softwareVersion {
            result["softwareVersion"] = softwareVersion
        }
        if let localIdentifier = self.localIdentifier {
            result["localIdentifier"] = localIdentifier
        }
        if let udiDeviceIdentifier = self.udiDeviceIdentifier {
            result["udiDeviceIdentifier"] = udiDeviceIdentifier
        }
        return result
    }
}

// MARK: - HKQuantitySample

extension HKQuantityType {
    var dictionary: [String: Any] {
        var result: [String: Any] = [:]
        result["aggregationStyle"] = self.aggregationStyle.stringValue
        return result
    }
}

extension HKQuantityAggregationStyle {
    var stringValue: String {
        switch self {
        case .cumulative: return "cumulative"
        case .discreteArithmetic: return "discreteArithmetic"
        case .discreteTemporallyWeighted: return "discreteTemporallyWeighted"
        case .discreteEquivalentContinuousLevel: return "discreteEquivalentContinuousLevel"
        @unknown default: return "unknown"
        }
    }
}

extension HKQuantity {
    func getDictionary(forUnit unit: HKUnit) -> [String: Any] {
        guard self.is(compatibleWith: unit) else {
            assertionFailure("Incompatibile Unit")
            return ["unit": "incompatibileUnit"]
        }
        var result: [String: Any] = [:]
        result["value"] = self.doubleValue(for: unit)
        result["unit"] = unit.unitString
        return result
    }
}

// MARK: - HKElectrocardiogram

@available(iOS 14.0, *)
extension HKElectrocardiogram.Classification {
    var stringValue: String {
        switch self {
        case .notSet: return "notSet"
        case .sinusRhythm: return "sinusRhythm"
        case .atrialFibrillation: return "atrialFibrillation"
        case .inconclusiveLowHeartRate: return "inconclusiveLowHeartRate"
        case .inconclusiveHighHeartRate: return "inconclusiveHighHeartRate"
        case .inconclusivePoorReading: return "inconclusivePoorReading"
        case .inconclusiveOther: return "inconclusiveOther"
        case .unrecognized: return "unrecognized"
        @unknown default: return "unknown"
        }
    }
}

@available(iOS 14.0, *)
extension HKElectrocardiogram.SymptomsStatus {
    var stringValue: String {
        switch self {
        case .notSet: return "notSet"
        case .none: return "none"
        case .present: return "present"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Workout

extension HKWorkoutActivityType {
    var stringValue: String {
        // TODO: Convert the whole enum to string
        return "\(self.rawValue)"
    }
}

extension HKWorkoutEvent {
    var dictionary: [String: Any] {
        var result: [String: Any] = [:]
        result["type"] = self.type.stringValue
        result["startDate"] = self.dateInterval.start.sampleDateTimeString
        result["endDate"] = self.dateInterval.end.sampleDateTimeString
        result["duration"] = self.dateInterval.duration
        if let metadata = self.metadata {
            result["metadata"] = metadata
        }
        return result
    }
}

extension HKWorkoutEventType {
    var stringValue: String {
        switch self {
        case .pause: return "pause"
        case .resume: return "resume"
        case .lap: return "lap"
        case .marker: return "marker"
        case .motionPaused: return "motionPaused"
        case .motionResumed: return "motionResumed"
        case .segment: return "segment"
        case .pauseOrResumeRequest: return "pauseOrResumeRequest"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - HealthDataType + HKUnit

fileprivate extension HealthDataType {
    
    var isUnitValid: Bool {
        var result = true
        if let quantityType = self.sampleType as? HKQuantityType {
            if let unit = self.unit {
                result = quantityType.is(compatibleWith: unit)
            } else {
                result = false
            }
        }
        assert(result, "Invalid Unit")
        return result
    }
    
    var unit: HKUnit? {
        switch self {
        // Activity
        case .stepCount: return HKUnit.defaultCount
        case .distanceWalkingRunning: return HKUnit.defaultLongDistance
        case .distanceCycling: return HKUnit.defaultLongDistance
        case .pushCount: return HKUnit.defaultCount
        case .distanceWheelChair: return HKUnit.defaultLongDistance
        case .swimmingStrokeCount: return HKUnit.defaultCount
        case .distanceSwimming: return HKUnit.defaultShortDistance
        case .distanceDownhillSnowSports: return HKUnit.defaultLongDistance
        case .basalEnergyBurned: return HKUnit.defaultEnergy
        case .activeEnergyBurned: return HKUnit.defaultEnergy
        case .flightsClimbed: return HKUnit.defaultCount
        case .nikeFuel: return HKUnit.defaultCount
        case .appleExerciseTime: return HKUnit.defaultTime
        case .appleStandHour: return nil
        case .appleStandTime: return HKUnit.defaultTime
        case .vo2Max: return HKUnit(from: "mL/min·kg")
        case .lowCardioFitnessEvent: return nil
        // Charasteristics
        case .activityMoveMode: return nil
        case .biologicalSex: return nil
        case .bloodType: return nil
        case .dateOfBirth: return nil
        case .fitzpatrickSkinType: return nil
        case .wheelchairUse: return nil
        // Vital Signs
        case .heartRate: return HKUnit.defaultCountOnTime
        case .lowHeartRateEvent: return nil
        case .highHeartRateEvent: return nil
        case .irregularHeartRhythmEvent: return nil
        case .restingHeartRate: return HKUnit.defaultCountOnTime
        case .heartRateVariabilitySDNN: return HKUnit(from: "ms")
        case .walkingHeartRateAverage: return HKUnit.defaultCountOnTime
        case .electrocardiogram: return nil
//        case .heartbeatSeries: return nil
        case .oxygenSaturation: return HKUnit(from: "%")
        case .bodyTemperature: return HKUnit.defaultTemperature
        case .bloodPressureSystolic: return HKUnit.defaultPressure
        case .bloodPressureDiastolic: return HKUnit.defaultPressure
        case .bloodPressure: return nil
        case .respiratoryRate: return HKUnit.defaultCountOnTime
        // Mindfulness and Sleep
        case .mindfulSession: return nil
        case .sleepAnalysis: return nil
        // Workouts
        case .workout: return nil
//        case .workoutRoute: return nil
        }
    }
}

fileprivate extension HKUnit {
    static let defaultCount = HKUnit(from: "count")
    static let defaultCountOnTime = HKUnit(from: "count/min")
    static let defaultEnergy = HKUnit(from: "kcal")
    static let defaultTime = HKUnit(from: "min")
    static let defaultShortDistance = HKUnit(from: "m")
    static let defaultLongDistance = HKUnit(from: "km")
    static let defaultPressure = HKUnit(from: "mmHg")
    static let defaultTemperature = HKUnit(from: "degC")
}

// MARK: - Utility

fileprivate extension Date {
    var sampleDateTimeString: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter.string(from: self)
    }
}

#endif
