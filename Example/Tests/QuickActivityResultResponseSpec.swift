//
//  QuickActivityResultResponseSpec.swift
//  ForYouAndMe_Tests
//
//  Specs for QuickActivityResultResponse — the typed response returned by
//  PATCH /v1/tasks/{taskId} for Quick Activities.
//
//  The body may include an optional `triggered_task_id` (Integer or null)
//  referencing a follow-up task (typically a Survey). When present, the app
//  must offer to launch the linked task; when absent, the existing
//  post-quick-activity flow continues.
//
//  See FUAM-3037 / FUAM-3038 / FUAM-3040 / FUAM-3069.
//

import Quick
import Nimble
import Foundation
@testable import ForYouAndMe

class QuickActivityResultResponseSpec: QuickSpec {
    override func spec() {

        describe("QuickActivityResultResponse decoding") {

            it("parses Integer triggered_task_id when present") {
                let json = "{\"triggered_task_id\": 12345}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId) == "12345"
            }

            it("parses String triggered_task_id as a fallback") {
                let json = "{\"triggered_task_id\": \"abc-123\"}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskId) == "abc-123"
            }

            it("returns nil when triggered_task_id key is absent") {
                let json = "{}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId).to(beNil())
            }

            it("returns nil when triggered_task_id is JSON null") {
                let json = "{\"triggered_task_id\": null}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId).to(beNil())
            }

            it("returns nil when triggered_task_id is an empty string") {
                let json = "{\"triggered_task_id\": \"\"}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskId).to(beNil())
            }

            it("ignores unrelated extra fields") {
                let json = "{\"triggered_task_id\": 42, \"extra\": 1, \"meta\": {\"x\": true}}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskId) == "42"
            }
        }

        describe("QuickActivityNextStep") {

            it("is .continueFlow when response carries no task id") {
                let response = QuickActivityResultResponse(taskId: nil)
                expect(QuickActivityNextStep(response: response)) == .continueFlow
            }

            it("is .continueFlow when task id is empty") {
                let response = QuickActivityResultResponse(taskId: "")
                expect(QuickActivityNextStep(response: response)) == .continueFlow
            }

            it("is .launchLinkedTask with the id when present") {
                let response = QuickActivityResultResponse(taskId: "task-99")
                expect(QuickActivityNextStep(response: response)) == .launchLinkedTask(taskId: "task-99")
            }
        }
    }
}
