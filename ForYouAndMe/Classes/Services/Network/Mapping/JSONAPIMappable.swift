//
//  JSONAPIMappable.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/05/2020.
//

import Foundation
import Moya

protocol JSONAPIMappable: JapxDecodable {
    static var includeList: String? { get }
    static var keyPath: String? { get }
    /// Opt-in for the resources the backend can return with a null `id`, meaning "not configured"
    /// (fast_jsonapi serializes an unsaved record as `"id": null` with HTTP 200). Japx rejects such a
    /// payload in `extractTypeIdPair` before any decoding happens, so for these types only the primary
    /// `data` id is normalised. Every other type keeps the strict behaviour through the default below.
    static var allowsNullIdentifier: Bool { get }
}

extension JSONAPIMappable {
    static var includeList: String? { nil }
    static var keyPath: String? { "data" }
    static var allowsNullIdentifier: Bool { false }
}

extension Response {
    /// Replaces a null `id` on the primary `data` resource with an empty string, so that Japx accepts it.
    /// No-op unless the target type opted in via `allowsNullIdentifier`, unless the payload is a single
    /// primary resource and unless its `id` key is present and null. `included` is left untouched.
    func normalizingNullIdentifier<T: JSONAPIMappable>(for type: T.Type) -> Response {
        guard T.allowsNullIdentifier,
              var json = (try? JSONSerialization.jsonObject(with: self.data)) as? [String: Any],
              var resource = json["data"] as? [String: Any],
              resource["id"] is NSNull else {
            return self
        }
        resource["id"] = ""
        json["data"] = resource
        guard let normalizedData = try? JSONSerialization.data(withJSONObject: json) else { return self }
        return Response(statusCode: self.statusCode, data: normalizedData, request: self.request, response: self.response)
    }
}
