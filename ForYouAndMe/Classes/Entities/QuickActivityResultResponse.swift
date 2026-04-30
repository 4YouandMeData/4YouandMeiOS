//
//  QuickActivityResultResponse.swift
//  ForYouAndMe
//
//  Response payload returned by POST /v1/tasks/{taskId}/result when the user
//  submits a Quick Activity. The optional `task_ids` array references one or
//  more follow-up tasks (typically a Survey) that the user is prompted to
//  start immediately. Today the array is expected to carry at most one entry,
//  but the contract is plural so the backend can grow without a client change.
//
//  See FUAM-3037.
//

import Foundation

struct QuickActivityResultResponse: Decodable, Equatable {

    let taskIds: [String]

    enum CodingKeys: String, CodingKey {
        case taskIds = "task_ids"
    }

    init(taskIds: [String]) {
        self.taskIds = taskIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.taskIds = (try container.decodeIfPresent([String].self, forKey: .taskIds)) ?? []
    }
}

extension QuickActivityResultResponse: PlainDecodable {}

enum QuickActivityNextStep: Equatable {
    case continueFlow
    case launchLinkedTask(taskId: String)

    init(response: QuickActivityResultResponse) {
        // Today the backend returns at most one linked task. Pick the first
        // non-empty id; ignore the rest until the UX is defined for N > 1.
        if let firstId = response.taskIds.first(where: { !$0.isEmpty }) {
            self = .launchLinkedTask(taskId: firstId)
        } else {
            self = .continueFlow
        }
    }
}
