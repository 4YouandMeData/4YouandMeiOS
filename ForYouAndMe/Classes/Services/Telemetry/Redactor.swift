//
//  Redactor.swift
//  ForYouAndMe
//
//  Central redaction. Every payload that reaches the Telemetry facade
//  goes through `Redactor.scrub(_:)` first. Typed builders for known
//  entity shapes (User, DiaryNote, …) live alongside as a second
//  layer — call sites should prefer the typed builders so they can't
//  forget a field.
//
//  Source of truth: docs/jam-telemetry.md.
//

import Foundation

public enum Redactor {

    /// Substring rules — applied case-insensitively against payload keys.
    /// Adding a new sensitive field name? Add it here and update
    /// docs/jam-telemetry.md.
    private static let denylistSubstrings: [String] = [
        // Tokens / credentials
        "password", "pin", "pincode", "pin_code",
        "token", "accesstoken", "access_token", "refreshtoken", "refresh_token",
        "firebase_token", "firebasetoken",
        "secret", "apikey", "api_key",
        "auth", "authorization", "authtoken", "auth_token",
        "cookie", "setcookie", "set_cookie", "session",
        "otp", "validationcode", "validation_code",
        // Contact PII
        "email", "phone", "phonenumber", "phone_number",
        "firstname", "lastname", "fullname",
        // PHI / health / diary content
        "transcription",
        "calories", "carbs", "mealtype",
        "units", "dosetype",
        "answer", "answers"
    ]

    /// "Naked" key names that are denied even when no substring matches
    /// (to avoid false positives on innocuous keys like "key", "code",
    /// "name", "content", "body" — all of which only matter as exact matches).
    private static let denylistExactKeys: Set<String> = [
        "key", "code", "name",
        "content", "body"
    ]

    /// Replaces values for sensitive keys with "[redacted]".
    /// Preserves the key so viewers can see *that* a token was passed —
    /// just not its value.
    public static func scrub(_ payload: [String: AnyHashable]) -> [String: AnyHashable] {
        var out: [String: AnyHashable] = [:]
        for (key, value) in payload {
            if isSensitive(key: key) {
                out[key] = "[redacted]"
            } else {
                out[key] = value
            }
        }
        return out
    }

    public static func isSensitive(key: String) -> Bool {
        let lower = key.lowercased()
        if denylistExactKeys.contains(lower) { return true }
        for needle in denylistSubstrings where lower.contains(needle) {
            return true
        }
        return false
    }

    // MARK: - HTTP body redaction

    /// Best-effort redaction of an HTTP body. Parses JSON when possible,
    /// walks keys, applies `scrub` semantics. For non-JSON content
    /// returns a placeholder.
    public static func httpBody(_ data: Data?, contentType: String?) -> String {
        guard let data = data, !data.isEmpty else { return "" }
        let isJSON = (contentType?.lowercased().contains("json") ?? false)
        if isJSON,
           let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            let redacted = redactJSON(json)
            if let outData = try? JSONSerialization.data(withJSONObject: redacted, options: [.fragmentsAllowed]),
               let str = String(data: outData, encoding: .utf8) {
                return str
            }
        }
        return "[non-JSON body, size=\(data.count) bytes]"
    }

    private static func redactJSON(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            for (key, v) in dict {
                if isSensitive(key: key) {
                    out[key] = "[redacted]"
                } else {
                    out[key] = redactJSON(v)
                }
            }
            return out
        }
        if let array = value as? [Any] {
            return array.map { redactJSON($0) }
        }
        return value
    }

    /// Strips known-secret query keys from a URL path/query.
    public static func scrubQueryString(_ url: URL?) -> String {
        guard let url = url else { return "" }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.path
        }
        if let items = components.queryItems {
            components.queryItems = items.map { item in
                if isSensitive(key: item.name) {
                    return URLQueryItem(name: item.name, value: "[redacted]")
                }
                return item
            }
        }
        let path = components.path
        if let query = components.percentEncodedQuery, !query.isEmpty {
            return "\(path)?\(query)"
        }
        return path
    }
}
