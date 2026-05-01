//
//  QuickActivityResultResponse.swift
//  ForYouAndMe
//
//  Response payload returned by PATCH /v1/tasks/{taskId} when the user
//  submits a Quick Activity. The optional `triggers_task_ids` array (nested
//  under `data.attributes` in the JSON:API envelope) lists ids of follow-up
//  tasks (typically a Survey) created server-side by the
//  `elaborate_triggers` hook. When present, the app prompts the user to
//  start the linked task immediately.
//
//  Backend contract (verified against staging): JSON:API envelope of the
//  updated task, with the linked-task ids exposed as
//  `data.attributes.triggers_task_ids: [Int]`.
//
//  See FUAM-3037 / FUAM-3040 / FUAM-3069.
//

import Foundation

struct QuickActivityResultResponse: Decodable, Equatable {

    let taskId: String?

    init(taskId: String?) {
        self.taskId = taskId
    }

    init(from decoder: Decoder) throws {
        // Navigate the JSON:API envelope: { "data": { "attributes": { "triggers_task_ids": [Int] } } }
        // Tolerate missing keys at every level so legacy / empty bodies decode to taskId == nil.
        let root = try? decoder.container(keyedBy: RootKeys.self)
        let data = try? root?.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
        let attrs = try? data?.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)

        let firstId: String? = {
            // Primary contract: array of Integers under data.attributes.triggers_task_ids.
            if let ints = try? attrs?.decodeIfPresent([Int].self, forKey: .triggersTaskIds),
               let first = ints?.first {
                return String(first)
            }
            // Tolerate string-encoded ids in case the contract shifts.
            if let strings = try? attrs?.decodeIfPresent([String].self, forKey: .triggersTaskIds),
               let first = strings?.first(where: { !$0.isEmpty }) {
                return first
            }
            return nil
        }()

        self.taskId = firstId
    }

    private enum RootKeys: String, CodingKey { case data }
    private enum DataKeys: String, CodingKey { case attributes }
    private enum AttributeKeys: String, CodingKey { case triggersTaskIds = "triggers_task_ids" }
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
