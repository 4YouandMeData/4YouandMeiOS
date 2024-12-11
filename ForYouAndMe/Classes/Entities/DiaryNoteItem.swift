//
//  DiaryNoteItem.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import Foundation

enum DiaryNoteItemType: String, Decodable {
    case text
    case audio
}

struct DiaryNoteItem {
    let id: String
    let type: String
    
    @DateValue<ISO8601Strategy>
    var diaryNoteId: Date

    @FailableEnumStringDecodable
    var diaryNoteType: DiaryNoteItemType?

    @NilIfEmptyString
    var title: String?

    @NilIfEmptyString
    var body: String?

    @URLDecodable
    var image: URL?

    @NilIfEmptyString
    var urlString: String?
    
    init?(from dictionary: [String: Any]) {
       guard let id = dictionary["id"] as? String,
             let type = dictionary["type"] as? String else {
           return nil
       }
       
        self.id = id
        self.type = type
        self.diaryNoteId = dictionary["diaryNoteId"] as? Date ?? Date()
        self.diaryNoteType = DiaryNoteItemType(rawValue: dictionary["diaryNoteType"] as? String ?? "text")
        self.title = dictionary["title"] as? String
        self.body = dictionary["body"] as? String
        if let imageUrlString = dictionary["image"] as? String {
           self.image = URL(string: imageUrlString)
        } else {
           self.image = nil
        }
        self.urlString = dictionary["attachment"] as? String
    }
}

extension DiaryNoteItem: JSONAPIMappable {
    
    static var includeList: String? = "diary_noteable"
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case diaryNoteId = "datetime_ref"
        case diaryNoteType = "diary_notable_type"
        case title
        case body
        case image
        case urlString = "attachment"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.diaryNoteId = try container.decode(DateValue<ISO8601Strategy>.self, forKey: .diaryNoteId).wrappedValue
        let diaryType = try? container.decodeIfPresent(String.self, forKey: .urlString)
        if let diaryType {
            self.diaryNoteType = .audio
        } else {
            self.diaryNoteType = .text
        }
        self.title = try? container.decodeIfPresent(String.self, forKey: .title)
        self.body = try container.decode(String.self, forKey: .body)
        self.image = try? container.decodeIfPresent(URL.self, forKey: .image)
    }
}
