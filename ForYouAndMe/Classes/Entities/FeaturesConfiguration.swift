//
//  FeaturesConfiguration.swift
//  ForYouAndMe
//
//  Created for FUAM-3342 — study-level feature flags served in the
//  study-configuration payload under the "features_configuration" key.
//

import Foundation

/// Per-feature entry inside `features_configuration`.
/// `order` is optional (the backend may omit it).
struct FeatureFlag: Codable {
    let enabled: Bool
    let order: Int?
}

/// Known feature keys served by the backend "Features Configuration".
/// Kept as an enum so call sites don't scatter raw string literals.
/// Decoding tolerates keys not listed here (they are simply ignored).
enum FeatureKey: String {
    case myDoses = "my_doses"
    case hotFlash = "hot_flash"
    case reflections
    case iHaveEaten = "i_have_eaten"
    case iHaveNoticed = "i_have_noticed"
    case weHaveNoticed = "we_have_noticed"
    case menstrualPeriod = "menstrual_period"
}

/// Map of raw feature-key -> flag. Backed by the raw string keys so unknown
/// / future feature keys survive parsing without breaking decoding.
struct FeaturesConfiguration: Codable {

    let flags: [String: FeatureFlag]

    init(flags: [String: FeatureFlag]) {
        self.flags = flags
    }

    /// Whether the given known feature is present and explicitly enabled.
    /// Absent key or `enabled == false` -> `false` (default = disabled).
    func isEnabled(_ key: FeatureKey) -> Bool {
        return self.flags[key.rawValue]?.enabled ?? false
    }

    /// Optional display order for a known feature, if the backend provided one.
    func order(_ key: FeatureKey) -> Int? {
        return self.flags[key.rawValue]?.order
    }
}
