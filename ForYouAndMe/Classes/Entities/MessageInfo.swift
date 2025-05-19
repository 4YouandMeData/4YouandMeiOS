//
//  MessageInfo.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/12/24.
//

enum MessageInfoParameter: String, Codable {
    case tabFeed = "TAB_FEED"
    case tabTask = "TAB_TASK"
    case tabDiary = "TAB_DIARY"
    case tabUserData = "TAB_USER_DATA"
    case tabStudyInfo = "TAB_STUDY_INFO"
    case pageChartDiary = "PAGE_CHART_DIARY"
    case pageIHaveNoticed = "PAGE_I_HAVE_NOTICED"
    case pageIHaveEeaten = "PAGE_I_HAVE_EATEN"
    case pageMyDoses = "PAGE_MY_DOSES"
    case unknown
        
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        
        self = MessageInfoParameter(rawValue: stringValue) ?? .unknown
    }
}

struct MessageInfo: Codable, Equatable {
    let id: String
    let type: String
    
    var title: String?
    var body: String?
    var buttonText: String?
    
    var location: MessageInfoParameter
}

extension MessageInfo: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case buttonText = "button_label"
        case location
    }
}

extension Array where Element == MessageInfo {
    func firstMessage(withLocation location: MessageInfoParameter) -> MessageInfo? {
        return self.first(where: { $0.location == location })
    }
    
    func messages(withLocation location: MessageInfoParameter) -> [MessageInfo] {
            return self.filter { $0.location == location }
    }
}
