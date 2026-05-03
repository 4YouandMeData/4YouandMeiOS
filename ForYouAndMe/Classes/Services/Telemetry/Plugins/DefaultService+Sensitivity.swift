//
//  DefaultService+Sensitivity.swift
//  ForYouAndMe
//
//  Marks API endpoints whose bodies must NEVER be captured by the
//  TelemetryPlugin — login flows, OTP exchange, push token, OAuth.
//
//  Source of truth: docs/jam-telemetry.md (sensitive endpoints).
//

import Foundation

extension DefaultService: SensitivityAwareTarget {
    var isSensitive: Bool {
        switch self {
        // Auth / OTP / token-bearing endpoints — bodies always suppressed.
        case .submitPhoneNumber,
             .verifyPhoneNumber,
             .emailLogin,
             .verifyEmail,
             .resendConfirmationEmail,
             .sendPushToken,
             .getTerraToken:
            return true
        default:
            return false
        }
    }
}
