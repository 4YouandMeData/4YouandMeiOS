//
//  QuickActivityResultResponse.swift
//  ForYouAndMe
//
//  Response payload returned by PATCH /v1/tasks/{taskId} when the user
//  submits a Quick Activity. The optional `triggered_task_id` references a
//  follow-up task (typically a Survey) created server-side by the
//  `elaborate_triggers` hook. When present, the app prompts the user to
//  start the linked task immediately.
//
//  Backend contract: see FUAM-3040 — field name `triggered_task_id`,
//  Integer or null. Wire fix for FUAM-3069.
//
//  See FUAM-3037.
//

import Foundation

struct QuickActivityResultResponse: Decodable, Equatable {

    let taskId: String?

    enum CodingKeys: String, CodingKey {
        case triggeredTaskId = "triggered_task_id"
    }

    init(taskId: String?) {
        self.taskId = taskId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Backend returns Integer; tolerate String in case the contract shifts.
        if let intId = try? container.decodeIfPresent(Int.self, forKey: .triggeredTaskId) {
            self.taskId = String(intId)
        } else if let stringId = try? container.decodeIfPresent(String.self, forKey: .triggeredTaskId),
                  !stringId.isEmpty {
            self.taskId = stringId
        } else {
            self.taskId = nil
        }
    }
}

extension QuickActivityResultResponse: PlainDecodable {}

enum QuickActivityNextStep: Equatable {
    case continueFlow
    case launchLinkedTask(taskId: String)

    init(response: QuickActivityResultResponse) {
        if let id = response.taskId, !id.isEmpty {
            self = .launchLinkedTask(taskId: id)
        } else {
            self = .continueFlow
        }
    }
}
