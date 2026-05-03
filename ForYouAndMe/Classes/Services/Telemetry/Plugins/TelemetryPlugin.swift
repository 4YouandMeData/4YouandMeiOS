//
//  TelemetryPlugin.swift
//  ForYouAndMe
//
//  Moya PluginType that emits structured `Telemetry.net.*` events for
//  every request and response. Replaces stock `NetworkLoggerPlugin`
//  in `NetworkApiGateway.setupDefaultProvider()` — the JamLog sink
//  takes care of the Console.app / Xcode debug-console mirroring.
//
//  Body capture is governed by `NetworkBodyCaptureMode`, set globally
//  via `FYAMManager.startup(..., networkBodyCaptureMode:)`.
//
//  Sensitive endpoints (auth, OTP, push token, OAuth) are flagged
//  on the TargetType (`var isSensitive: Bool`) and ALWAYS suppress
//  body capture regardless of the mode.
//

import Foundation
import Moya

/// Configures how much of the HTTP body the plugin captures.
public enum NetworkBodyCaptureMode {
    case none
    case errorsOnly
    case truncated
}

/// Endpoints can opt out of body capture by conforming to this protocol
/// and returning `true`. Bodies (request + response) are replaced with
/// "[body=suppressed]" regardless of the global capture mode.
public protocol SensitivityAwareTarget {
    var isSensitive: Bool { get }
}

final class TelemetryPlugin: PluginType {

    private let bodyCaptureMode: NetworkBodyCaptureMode
    private let requestBodyMaxBytes = 1024
    private let responseBodyMaxBytes = 4096

    // In-flight pairing so request/response share a correlation_id. Keyed by
    // the URL absoluteString (as a hashable proxy for the URLRequest).
    // FIFO pop on didReceive handles the dominant sequential-API pattern;
    // for concurrent identical-URL calls the worst case is reordering of
    // pairs (still useful — never breaks).
    private struct Pending {
        let correlationId: String
        let startTime: Date
    }
    private let pendingQueue = DispatchQueue(label: "com.4youandme.ios.telemetryplugin.pending")
    private var pending: [String: [Pending]] = [:]

    init(bodyCaptureMode: NetworkBodyCaptureMode) {
        self.bodyCaptureMode = bodyCaptureMode
    }

    // MARK: - PluginType

    func willSend(_ request: RequestType, target: TargetType) {
        guard let urlRequest = request.request else { return }
        let key = urlRequest.url?.absoluteString ?? "<no-url>"
        let correlationId = UUID().uuidString
        pendingQueue.sync {
            pending[key, default: []].append(Pending(correlationId: correlationId, startTime: Date()))
        }

        let isSensitive = (target as? SensitivityAwareTarget)?.isSensitive ?? false
        let method = urlRequest.httpMethod ?? "GET"
        let path = Redactor.scrubQueryString(urlRequest.url)
        let bodyPreview = capturedRequestBody(urlRequest: urlRequest, isSensitive: isSensitive)

        Telemetry.net.request(
            method: method,
            path: path,
            correlationId: correlationId,
            bodyPreview: bodyPreview,
            isSensitive: isSensitive
        )
    }

    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        switch result {
        case .success(let response):
            handle(response: response, target: target)
        case .failure(let error):
            handle(error: error, target: target)
        }
    }

    // MARK: - Helpers

    private func popPending(forKey key: String) -> Pending? {
        pendingQueue.sync {
            guard var queue = pending[key], !queue.isEmpty else { return nil }
            let pop = queue.removeFirst()
            if queue.isEmpty {
                pending.removeValue(forKey: key)
            } else {
                pending[key] = queue
            }
            return pop
        }
    }

    private func handle(response: Response, target: TargetType) {
        let urlRequest = response.request
        let isSensitive = (target as? SensitivityAwareTarget)?.isSensitive ?? false
        let key = urlRequest?.url?.absoluteString ?? "<no-url>"
        let pop = popPending(forKey: key)
        let correlationId = pop?.correlationId ?? UUID().uuidString
        let durationMs = pop.map { Int(Date().timeIntervalSince($0.startTime) * 1000.0) } ?? -1

        let method = urlRequest?.httpMethod ?? "?"
        let path = Redactor.scrubQueryString(urlRequest?.url)
        let bodyPreview = capturedResponseBody(response: response, isSensitive: isSensitive)
        let errorCategory: String? = (response.statusCode >= 400) ? "http_\(response.statusCode)" : nil

        Telemetry.net.response(
            method: method,
            path: path,
            correlationId: correlationId,
            status: response.statusCode,
            durationMs: durationMs,
            responseSize: response.data.count,
            bodyPreview: bodyPreview,
            errorCategory: errorCategory,
            isSensitive: isSensitive
        )
    }

    private func handle(error: MoyaError, target: TargetType) {
        let urlRequest = error.response?.request
        let isSensitive = (target as? SensitivityAwareTarget)?.isSensitive ?? false
        let key = urlRequest?.url?.absoluteString ?? "<no-url>"
        let pop = popPending(forKey: key)
        let correlationId = pop?.correlationId ?? UUID().uuidString
        let durationMs = pop.map { Int(Date().timeIntervalSince($0.startTime) * 1000.0) } ?? -1
        let method = urlRequest?.httpMethod ?? "?"
        let path = Redactor.scrubQueryString(urlRequest?.url)

        // If we have an HTTP response, treat it like a normal response.
        if let response = error.response {
            let bodyPreview = capturedResponseBody(response: response, isSensitive: isSensitive)
            Telemetry.net.response(
                method: method,
                path: path,
                correlationId: correlationId,
                status: response.statusCode,
                durationMs: durationMs,
                responseSize: response.data.count,
                bodyPreview: bodyPreview,
                errorCategory: "moya_\(error.errorCode)",
                isSensitive: isSensitive
            )
        } else {
            Telemetry.net.transportError(
                method: method,
                path: path,
                correlationId: correlationId,
                durationMs: durationMs,
                underlying: error,
                isSensitive: isSensitive
            )
        }
    }

    // MARK: - Body capture

    private func capturedRequestBody(urlRequest: URLRequest, isSensitive: Bool) -> String? {
        if isSensitive { return "[body=suppressed]" }
        switch bodyCaptureMode {
        case .none, .errorsOnly:
            return nil
        case .truncated:
            return preview(data: urlRequest.httpBody,
                           contentType: urlRequest.value(forHTTPHeaderField: "Content-Type"),
                           maxBytes: requestBodyMaxBytes)
        }
    }

    private func capturedResponseBody(response: Response, isSensitive: Bool) -> String? {
        if isSensitive { return "[body=suppressed]" }
        let contentType = response.response?.allHeaderFields["Content-Type"] as? String
        switch bodyCaptureMode {
        case .none:
            return nil
        case .errorsOnly:
            guard response.statusCode >= 400 else { return nil }
            // Full but redacted on error.
            return preview(data: response.data, contentType: contentType, maxBytes: Int.max)
        case .truncated:
            let cap = response.statusCode >= 400 ? Int.max : responseBodyMaxBytes
            return preview(data: response.data, contentType: contentType, maxBytes: cap)
        }
    }

    private func preview(data: Data?, contentType: String?, maxBytes: Int) -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        let truncated: Data = (data.count > maxBytes) ? data.prefix(maxBytes) : data
        var redacted = Redactor.httpBody(truncated, contentType: contentType)
        if data.count > maxBytes {
            redacted += " [...truncated, original=\(data.count) bytes]"
        }
        return redacted
    }
}
