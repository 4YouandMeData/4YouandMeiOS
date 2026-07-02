//
//  ClientMetadataPlugin.swift
//  ForYouAndMe
//
//  Moya PluginType that attaches client/agent metadata headers to every
//  mutating API request (POST / PUT / PATCH / DELETE). GET (and any other
//  non-mutating) requests are returned untouched.
//
//  The backend (FUAM-3466) captures these `X-Client-*` headers; they are
//  harmless if unread, so the client ships ahead of the backend.
//
//  `Bundle.main` resolves to the HOST app at runtime (e.g. OurTransitions /
//  BetaTrack), which is exactly what we want: the host app's version / build /
//  bundle id, not the framework's.
//
//  Note on the timestamp: the existing `ISO8601Strategy` emits UTC (`Z`).
//  Here we deliberately want the DEVICE LOCAL time with its UTC offset
//  (e.g. `+02:00`), so this plugin uses a dedicated `ISO8601DateFormatter`
//  with `.withInternetDateTime` + `.withFractionalSeconds` and
//  `timeZone = .current`. Computed per-request.
//

import Foundation
import Moya
import UIKit

final class ClientMetadataPlugin: PluginType {

    enum HeaderKey {
        static let platform = "X-Client-Platform"
        static let appVersion = "X-Client-App-Version"
        static let osVersion = "X-Client-OS-Version"
        static let appBuild = "X-Client-App-Build"
        static let appId = "X-Client-App-Id"
        static let timestamp = "X-Client-Timestamp"
    }

    /// Local-time ISO8601 formatter with fractional seconds and the device's
    /// current UTC offset (e.g. `2026-06-29T14:03:11.123+02:00`).
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    // MARK: - PluginType

    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        guard let method = request.httpMethod?.uppercased(),
              ["POST", "PUT", "PATCH", "DELETE"].contains(method) else {
            return request
        }

        var request = request
        for (key, value) in self.metadataHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    // MARK: - Private

    private func metadataHeaders() -> [String: String] {
        return [
            HeaderKey.platform: "ios",
            HeaderKey.appVersion: Bundle.main.versionName,
            HeaderKey.osVersion: UIDevice.current.systemVersion,
            HeaderKey.appBuild: String(Bundle.main.buildNumber),
            HeaderKey.appId: Bundle.main.bundleIdentifier ?? "",
            HeaderKey.timestamp: self.timestampFormatter.string(from: Date())
        ]
    }
}
