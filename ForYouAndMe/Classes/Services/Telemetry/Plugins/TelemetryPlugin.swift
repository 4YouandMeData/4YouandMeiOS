//
//  TelemetryPlugin.swift
//  ForYouAndMe
//
//  Moya PluginType that emits structured `Telemetry.Net.*` events for
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
    // Body caps are tuned for typical JSON:API payloads — see
    // docs/jam-telemetry.md for the rationale and operational notes.
    private let requestBodyMaxBytes = 10 * 1024              // 10 KB
    private let responseBodyMaxBytes = 40 * 1024             // 40 KB (idempotent reads)
    private let responseBodyMutatingMaxBytes = 100 * 1024    // 100 KB (POST/PUT/PATCH 2xx — full mutated entity)

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

        Telemetry.Net.request(
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

        Telemetry.Net.response(.init(
            method: method,
            path: path,
            correlationId: correlationId,
            status: response.statusCode,
            durationMs: durationMs,
            responseSize: response.data.count,
            bodyPreview: bodyPreview,
            errorCategory: errorCategory,
            isSensitive: isSensitive
        ))
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
            Telemetry.Net.response(.init(
                method: method,
                path: path,
                correlationId: correlationId,
                status: response.statusCode,
                durationMs: durationMs,
                responseSize: response.data.count,
                bodyPreview: bodyPreview,
                errorCategory: "moya_\(error.errorCode)",
                isSensitive: isSensitive
            ))
        } else {
            Telemetry.Net.transportError(
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
            let cap = capForResponse(method: response.request?.httpMethod, status: response.statusCode)
            return preview(data: response.data, contentType: contentType, maxBytes: cap)
        }
    }

    /// Per-method response cap selection (FUAM-3081). Mutating-method 2xx
    /// responses get a 100 KB cap because the response often carries the
    /// freshly-mutated entity in full and that's exactly what we want to
    /// see in a Jam recording. Idempotent reads stay at the smaller default.
    /// Non-2xx is uncapped (full but redacted) regardless of method.
    private func capForResponse(method: String?, status: Int) -> Int {
        if status >= 400 { return Int.max }
        let mutatingMethods: Set<String> = ["POST", "PUT", "PATCH"]
        if let method = method?.uppercased(), mutatingMethods.contains(method) {
            return responseBodyMutatingMaxBytes
        }
        return responseBodyMaxBytes
    }

    /// Hard ceiling on body size we'll attempt to parse. Walking and
    /// redacting JSON has measurable cost; bodies larger than this are
    /// reported as a placeholder. Picked to comfortably cover normal
    /// REST traffic (study config, feeds, tasks) while bounding pathological
    /// cases (image uploads / very large uploads).
    private let parseInputCeilingBytes = 256 * 1024

    /// Redact the FULL body first, then truncate the resulting redacted
    /// string. This is critical: truncating raw bytes before parsing
    /// breaks JSON mid-stream and falls through to the "non-JSON body"
    /// placeholder — losing the redacted JSON exactly when the response
    /// is most diagnostic.
    private func preview(data: Data?, contentType: String?, maxBytes: Int) -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        guard data.count <= parseInputCeilingBytes else {
            return "[body too large to parse, size=\(data.count) bytes]"
        }
        var redacted = Redactor.httpBody(data, contentType: contentType)
        if maxBytes != Int.max && redacted.count > maxBytes {
            let head = String(redacted.prefix(maxBytes))
            redacted = "\(head) [...truncated, original_body=\(data.count) bytes]"
        }
        return redacted
    }
}
