//
//  HealthDataType+Characteristic.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/21.
//

import Foundation

#if HEALTHKIT
import HealthKit

extension HealthDataType {
    
    var characteristicTypeKey: String? {
        switch self {
        case .activityMoveMode,
             .biologicalSex,
             .bloodType,
             .dateOfBirth,
             .fitzpatrickSkinType,
             .wheelchairUse:
            return self.rawValue
        default: return nil
        }
    }
    
    func characteristicValueDataString(healthStore: HKHealthStore) -> String? {
        switch self {
        case .activityMoveMode:
            if #available(iOS 14.0, *) {
                return try? healthStore.activityMoveMode().activityMoveMode.stringData
            } else {
                return nil
            }
        case .biologicalSex: return try? healthStore.biologicalSex().biologicalSex.stringData
        case .bloodType: return try? healthStore.bloodType().bloodType.stringData
        case .dateOfBirth: return
            try? healthStore.dateOfBirthComponents().date?.healthDateString
        case .fitzpatrickSkinType: return try? healthStore.fitzpatrickSkinType().skinType.stringData
        case .wheelchairUse: return try? healthStore.wheelchairUse().wheelchairUse.stringData
        default: return nil
        }
    }
}

@available(iOS 14.0, *)
extension HKActivityMoveMode {
    var stringData: String {
        switch self {
        case .activeEnergy: return "activeEnergy"
        case .appleMoveTime: return "appleMoveTime"
        @unknown default: return "unknown"
        }
    }
}

extension HKBiologicalSex {
    var stringData: String {
        switch self {
        case .male: return "male"
        case .female: return "female"
        case .notSet: return "notSet"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}

extension HKBloodType {
    var stringData: String {
        switch self {
        case .aNegative: return "aNegative"
        case .notSet: return "notSet"
        case .aPositive: return "aPositive"
        case .bPositive: return "bPositive"
        case .bNegative: return "bNegative"
        case .abPositive: return "abPositive"
        case .abNegative: return "abNegative"
        case .oPositive: return "oPositive"
        case .oNegative: return "oNegative"
        @unknown default: return "unknown"
        }
    }
}

extension HKFitzpatrickSkinType {
    var stringData: String {
        switch self {
        case .I: return "I"
        case .II: return "II"
        case .III: return "III"
        case .IV: return "IV"
        case .V: return "V"
        case .VI: return "VI"
        case .notSet: return "notSet"
        @unknown default: return "unknown"
        }
    }
}

extension HKWheelchairUse {
    var stringData: String {
        switch self {
        case .no: return "no"
        case .notSet: return "notSet"
        case .yes: return "yes"
        @unknown default: return "unknown"
        }
    }
}

#endif
