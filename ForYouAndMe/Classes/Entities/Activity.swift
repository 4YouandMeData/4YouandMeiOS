//
//  Activity.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 05/08/2020.
//

import Foundation

enum ActivityBehavior {
    case info(body: String)
    case externalLink(url: URL)
    case task(taskType: TaskType)
}

struct Activity {
    let id: String
    let type: String
    
    @NilIfEmptyString
    var title: String?
    @NilIfEmptyString
    var body: String?
    @ImageDecodable
    var image: UIImage?
    @NilIfEmptyString
    var buttonText: String?
    @NilIfEmptyString
    var infoBody: String?
    let externalLinkUrl: URL?
    @EnumStringDecodable
    var taskType: TaskType?
    
    @ColorDecodable
    var startColor: UIColor?
    @ColorDecodable
    var endColor: UIColor?
}

extension Activity: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body = "description"
        case image
        case buttonText = "task_action_button_label"
        case infoBody = "info_body"
        case externalLinkUrl = "external_link_url"
        case taskType = "activity_type"
        case startColor = "start_color"
        case endColor = "end_color"
    }
}

extension Activity {
    var behavior: ActivityBehavior? {
        if let infoBody = self.infoBody {
            return .info(body: infoBody)
        } else if let externalLinkUrl = self.externalLinkUrl {
            return .externalLink(url: externalLinkUrl)
        } else if let taskType = self.taskType {
            return .task(taskType: taskType)
        } else {
            return nil
        }
    }
}
