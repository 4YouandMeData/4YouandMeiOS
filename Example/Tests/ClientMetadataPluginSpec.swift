//
//  ClientMetadataPluginSpec.swift
//  ForYouAndMe_Tests
//
//  Verifies that ClientMetadataPlugin attaches the six `X-Client-*` metadata
//  headers to mutating requests (POST/PUT/PATCH/DELETE) and leaves
//  non-mutating requests (GET) untouched (FUAM-3467).
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class ClientMetadataPluginSpec: QuickSpec {
    override class func spec() {

        let url = URL(string: "https://example.com/v1/diary_notes")!

        // A throwaway TargetType — `prepare` keys off the URLRequest's
        // httpMethod, never the target, so a minimal stub is sufficient.
        struct DummyTarget: TargetType {
            var baseURL: URL { URL(string: "https://example.com")! }
            var path: String { "" }
            var method: Moya.Method { .get }
            var task: Task { .requestPlain }
            var headers: [String: String]? { nil }
            var sampleData: Data { Data() }
        }

        func makeRequest(method: String) -> URLRequest {
            var request = URLRequest(url: url)
            request.httpMethod = method
            return request
        }

        let mutatingHeaderKeys = [
            "X-Client-Platform",
            "X-Client-App-Version",
            "X-Client-OS-Version",
            "X-Client-App-Build",
            "X-Client-App-Id",
            "X-Client-Timestamp"
        ]

        // ISO8601 with internet date-time, fractional seconds and a UTC offset
        // (either `Z` or `±HH:MM`). On the test host the device timezone may be
        // UTC, so accept both forms.
        let iso8601OffsetRegex = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}([+-]\\d{2}:\\d{2}|Z)$"

        var plugin: ClientMetadataPlugin!
        let target = DummyTarget()

        beforeEach {
            plugin = ClientMetadataPlugin()
        }

        describe("ClientMetadataPlugin.prepare") {

            context("on mutating methods") {
                ["POST", "PUT", "PATCH", "DELETE"].forEach { method in
                    it("adds all six X-Client-* headers for \(method)") {
                        let prepared = plugin.prepare(makeRequest(method: method), target: target)
                        let headers = prepared.allHTTPHeaderFields ?? [:]

                        mutatingHeaderKeys.forEach { key in
                            expect(headers[key]).toNot(beNil(), description: "missing \(key) on \(method)")
                        }

                        expect(headers["X-Client-Platform"]).to(equal("ios"))
                        expect(headers["X-Client-App-Version"]).to(equal(Bundle.main.versionName))
                        expect(headers["X-Client-OS-Version"]).to(equal(UIDevice.current.systemVersion))
                        expect(headers["X-Client-App-Build"]).to(equal(String(Bundle.main.buildNumber)))
                        expect(headers["X-Client-App-Id"]).to(equal(Bundle.main.bundleIdentifier ?? ""))

                        let timestamp = headers["X-Client-Timestamp"] ?? ""
                        expect(timestamp).to(match(iso8601OffsetRegex))
                    }
                }
            }

            context("on non-mutating methods") {
                it("leaves headers untouched for GET") {
                    let prepared = plugin.prepare(makeRequest(method: "GET"), target: target)
                    let headers = prepared.allHTTPHeaderFields ?? [:]

                    mutatingHeaderKeys.forEach { key in
                        expect(headers[key]).to(beNil(), description: "unexpected \(key) on GET")
                    }
                }

                it("preserves pre-existing headers on GET") {
                    var request = makeRequest(method: "GET")
                    request.setValue("application/json", forHTTPHeaderField: "Content-type")
                    let prepared = plugin.prepare(request, target: target)
                    expect(prepared.value(forHTTPHeaderField: "Content-type")).to(equal("application/json"))
                }
            }
        }
    }
}
