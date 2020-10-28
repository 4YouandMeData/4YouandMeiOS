//
//  Activity.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 05/08/2020.
//

import Foundation

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
    @FailableEnumStringDecodable
    var taskType: TaskType?
    
    @ColorDecodable
    var startColor: UIColor?
    @ColorDecodable
    var endColor: UIColor?
    @ColorDecodable
    var cardColor: UIColor?
    
    let pages: [Page]
    let welcomePage: Page
    let successPage: Page?
    
    let rescheduleTimes: Int?
}

extension Activity: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body = "description"
        case image
        case buttonText = "task_action_button_label"
        case taskType = "activity_type"
        case startColor = "start_color"
        case endColor = "end_color"
        case cardColor = "card_color"
        case pages
        case welcomePage = "welcome_page"
        case successPage = "success_page"
        case rescheduleTimes = "reschedule_times"
    }
}
