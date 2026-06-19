//
//  IntegrationProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/10/2020.
//

import Foundation

class IntegrationProvider {
    
    private static var integrationDatas: [IntegrationData] = []
    
    static func initialize(withIntegrationDatas integrationDatas: [IntegrationData]) {
        self.integrationDatas = integrationDatas
    }
    
    static func oAuthIntegration(withName name: String) -> Integration? {
        guard let matchingOauthIntegration = self.integrationDatas.first(where: { $0.name == name }) else {
            return nil
        }
        return Integration(rawValue: matchingOauthIntegration.name)
    }
    
    static func oAuthIntegrations() -> [Integration] {
        return self.integrationDatas.filter { $0.oAuthAvailable }.compactMap { Integration(rawValue: $0.name) }
    }

    /// Whether the study's backend declares SensorKit among its supported integrations.
    /// The raw backend key is exactly "sensor_kit" (matched against `IntegrationData.name`).
    /// Used to surface the SensorKit permission row even for users who skipped SensorKit in
    /// onboarding and therefore have no SensorKit identity yet (FUAM-3432).
    static func isSensorKitSupported() -> Bool {
        return self.integrationDatas.contains { $0.name == "sensor_kit" }
    }
}
