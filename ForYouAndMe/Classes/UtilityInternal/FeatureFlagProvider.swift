//
//  FeatureFlagProvider.swift
//  ForYouAndMe
//
//  Created for FUAM-3342 — exposes the study's feature flags
//  (from GlobalConfig.featuresConfiguration) to the UI layer, mirroring
//  IntegrationProvider / OnboardingSectionProvider.
//

import Foundation

class FeatureFlagProvider {

    private static var featuresConfiguration: FeaturesConfiguration?

    static func initialize(withFeaturesConfiguration featuresConfiguration: FeaturesConfiguration?) {
        self.featuresConfiguration = featuresConfiguration
    }

    /// Whether the study opted into the given feature (default = disabled).
    /// Returns `false` when `features_configuration` is absent, the key is
    /// absent, or `enabled` is `false`.
    static func isFeatureEnabled(_ key: FeatureKey) -> Bool {
        return self.featuresConfiguration?.isEnabled(key) ?? false
    }
}
