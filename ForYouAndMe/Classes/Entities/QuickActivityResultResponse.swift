//
//  QuickActivityResultResponse.swift
//  ForYouAndMe
//
//  Response payload returned by POST /v1/tasks/{taskId}/result when the user
//  submits a Quick Activity. The optional `task_id` references a follow-up
//  task (typically a Survey) that the user is prompted to start immediately.
//
//  See FUAM-3037.
//

import Foundation

struct QuickActivityResultResponse: Decodable, Equatable {

    let taskId: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
    }

    init(taskId: String?) {
        self.taskId = taskId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
    }
}

extension QuickActivityResultResponse: PlainDecodable {}

enum QuickActivityNextStep: Equatable {
    case continueFlow
    case launchLinkedTask(taskId: String)

    init(response: QuickActivityResultResponse) {
        if let taskId = response.taskId, !taskId.isEmpty {
            self = .launchLinkedTask(taskId: taskId)
        } else {
            self = .continueFlow
        }
    }
}
