//
//  Telemetry+Net.swift
//  ForYouAndMe
//
//  Network telemetry builders. Used by `TelemetryPlugin` (the Moya
//  PluginType registered in NetworkApiGateway). Direct callers
//  shouldn't normally need these — the plugin emits for every request.
//

import Foundation

extension Telemetry {
    public enum net {

        public static func request(method: String,
                                   path: String,
                                   correlationId: String,
                                   bodyPreview: String?,
                                   isSensitive: Bool,
                                   file: String = #fileID,
                                   function: String = #function,
                                   line: UInt = #line) {
            var payload: [String: AnyHashable] = [
                "method": method,
                "path": path,
                "correlation_id": correlationId,
                "sensitive": isSensitive
            ]
            if let bodyPreview = bodyPreview, !bodyPreview.isEmpty {
                payload["request_body"] = bodyPreview
            }
            track(TelemetryEvent(
                category: .net,
                name: "request",
                level: .info,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        public static func response(method: String,
                                    path: String,
                                    correlationId: String,
                                    status: Int,
                                    durationMs: Int,
                                    responseSize: Int,
                                    bodyPreview: String?,
                                    errorCategory: String?,
                                    isSensitive: Bool,
                                    file: String = #fileID,
                                    function: String = #function,
                                    line: UInt = #line) {
            let level: TelemetryLevel = {
                switch status {
                case 200..<400: return .info
                case 400..<500: return .warn
                default: return .error
                }
            }()

            var payload: [String: AnyHashable] = [
                "method": method,
                "path": path,
                "correlation_id": correlationId,
                "status": status,
                "duration_ms": durationMs,
                "response_size": responseSize,
                "sensitive": isSensitive
            ]
            if let bodyPreview = bodyPreview, !bodyPreview.isEmpty {
                payload["response_body"] = bodyPreview
            }
            if let errorCategory = errorCategory {
                payload["error_category"] = errorCategory
            }
            track(TelemetryEvent(
                category: .net,
                name: "response",
                level: level,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }

        /// Emitted when the underlying URL session reports an error
        /// (no HTTP response). Status defaults to 0 to distinguish.
        public static func transportError(method: String,
                                          path: String,
                                          correlationId: String,
                                          durationMs: Int,
                                          underlying: Error,
                                          isSensitive: Bool,
                                          file: String = #fileID,
                                          function: String = #function,
                                          line: UInt = #line) {
            let nsError = underlying as NSError
            let payload: [String: AnyHashable] = [
                "method": method,
                "path": path,
                "correlation_id": correlationId,
                "status": 0,
                "duration_ms": durationMs,
                "error_domain": nsError.domain,
                "error_code": nsError.code,
                "error_description": nsError.localizedDescription,
                "sensitive": isSensitive
            ]
            track(TelemetryEvent(
                category: .net,
                name: "transport.error",
                level: .error,
                payload: payload,
                trace: TelemetryTrace(file: file, function: function, line: line)
            ))
        }
    }
}
