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

            it("parses task_ids when present") {
                let json = "{\"task_ids\": [\"abc-123\", \"abc-456\"]}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskIds) == ["abc-123", "abc-456"]
            }

            it("returns an empty array when task_ids key is absent") {
                let json = "{}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskIds) == []
            }

            it("returns an empty array when task_ids is JSON null") {
                let json = "{\"task_ids\": null}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskIds) == []
            }

            it("returns an empty array when task_ids is an empty list") {
                let json = "{\"task_ids\": []}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskIds) == []
            }

            it("ignores unrelated extra fields") {
                let json = "{\"task_ids\": [\"abc\"], \"extra\": 42, \"meta\": {\"x\": true}}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskIds) == ["abc"]
            }
        }

        describe("QuickActivityNextStep") {

            it("is .continueFlow when response carries no task ids") {
                let response = QuickActivityResultResponse(taskIds: [])
                expect(QuickActivityNextStep(response: response)) == .continueFlow
            }

            it("is .continueFlow when every id is empty") {
                let response = QuickActivityResultResponse(taskIds: ["", ""])
                expect(QuickActivityNextStep(response: response)) == .continueFlow
            }

            it("is .launchLinkedTask with the first non-empty id when present") {
                let response = QuickActivityResultResponse(taskIds: ["", "task-99", "task-100"])
                expect(QuickActivityNextStep(response: response)) == .launchLinkedTask(taskId: "task-99")
            }
        }
    }
}
