//
//  QuickActivityResultResponseSpec.swift
//  ForYouAndMe_Tests
//
//  Specs for QuickActivityResultResponse — the new typed response returned by
//  POST /v1/tasks/{taskId}/result for Quick Activities.
//
//  The body may include an optional `task_id` referencing a follow-up task
//  (typically a Survey). When present, the app must offer to launch the linked
//  task; when absent, the existing post-quick-activity flow continues.
//
//  See FUAM-3037 / FUAM-3038.
//

import Quick
import Nimble
import Foundation
@testable import ForYouAndMe

class QuickActivityResultResponseSpec: QuickSpec {
    override func spec() {

        describe("QuickActivityResultResponse decoding") {

            it("parses task_id when present") {
                let json = "{\"task_id\": \"abc-123\"}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId) == "abc-123"
            }

            it("returns nil taskId when task_id key is absent") {
                let json = "{}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId).to(beNil())
            }

            it("returns nil taskId when task_id is JSON null") {
                let json = "{\"task_id\": null}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId).to(beNil())
            }

            it("ignores unrelated extra fields") {
                let json = "{\"task_id\": \"abc\", \"extra\": 42, \"meta\": {\"x\": true}}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskId) == "abc"
            }
        }

        describe("QuickActivityNextStep") {

            it("is .continueFlow when response has no task id") {
                let response = QuickActivityResultResponse(taskId: nil)
                expect(QuickActivityNextStep(response: response)) == .continueFlow
            }

            it("is .launchLinkedTask with the parsed id when task_id is present") {
                let response = QuickActivityResultResponse(taskId: "task-99")
                expect(QuickActivityNextStep(response: response)) == .launchLinkedTask(taskId: "task-99")
            }
        }
    }
}
