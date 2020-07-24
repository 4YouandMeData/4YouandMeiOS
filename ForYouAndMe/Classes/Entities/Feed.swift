//
//  Feed.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/07/2020.
//

import Foundation

enum FeedBehavior {
    case info(body: String)
    case externalLink(url: URL)
    case task(taskId: String, taskType: TaskType)
}

struct Feed {
    let title: String
    let body: String
    let image: UIImage?
    let creationDate: Date
    let buttonText: String?
    let infoBody: String?
    let externalLinkUrl: URL?
    let taskId: String?
    let taskType: TaskType?
    
    let startColor: UIColor
    let endColor: UIColor
}

extension Feed {
    var behavior: FeedBehavior? {
        if let infoBody = self.infoBody {
            return .info(body: infoBody)
        } else if let externalLinkUrl = self.externalLinkUrl {
            return .externalLink(url: externalLinkUrl)
        } else if let taskId = self.taskId, let taskType = self.taskType {
            return .task(taskId: taskId, taskType: taskType)
        } else {
            return nil
        }
    }
}
