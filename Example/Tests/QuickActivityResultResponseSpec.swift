//
//  QuickActivityResultResponseSpec.swift
//  ForYouAndMe_Tests
//
//  Specs for QuickActivityResultResponse — the typed response returned by
//  PATCH /v1/tasks/{taskId} for Quick Activities.
//
//  The body is a JSON:API envelope. The optional linked task ids live at
//  `data.attributes.triggers_task_ids` (array of Integers). When the array
//  is non-empty, the app must offer to launch the first linked task.
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

            it("parses Integer triggers_task_ids when present") {
                let json = """
                {"data":{"id":"105591","type":"task","attributes":{"triggers_task_ids":[105592]}}}
                """.data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId) == "105592"
            }

            it("picks the first id when multiple are returned") {
                let json = """
                {"data":{"attributes":{"triggers_task_ids":[105592, 105600]}}}
                """.data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskId) == "105592"
            }

            it("parses String-encoded ids as a fallback") {
                let json = """
                {"data":{"attributes":{"triggers_task_ids":["abc-123"]}}}
                """.data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskId) == "abc-123"
            }

            it("returns nil when triggers_task_ids is absent") {
                let json = """
                {"data":{"id":"105591","type":"task","attributes":{}}}
                """.data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId).to(beNil())
            }

            it("returns nil when triggers_task_ids is an empty array") {
                let json = """
                {"data":{"attributes":{"triggers_task_ids":[]}}}
                """.data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded?.taskId).to(beNil())
            }

            it("returns nil when the data envelope is missing entirely") {
                let json = "{}".data(using: .utf8)!
                let decoded = try? JSONDecoder().decode(QuickActivityResultResponse.self, from: json)
                expect(decoded).toNot(beNil())
                expect(decoded?.taskId).to(beNil())
            }

            it("ignores unrelated extra fields") {
                let json = """
                {"data":{"id":"1","type":"task","attributes":{"triggers_task_ids":[42],"from":"2026-04-30T22:00:00.000Z","skippable":false}},"included":[],"meta":{}}
                """.data(using: .utf8)!
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
