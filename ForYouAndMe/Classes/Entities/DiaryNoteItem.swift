//
//  DiaryNoteItem.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import Foundation

enum DiaryNoteItemType: String {
    case text
    case audio
}

struct DiaryNoteItem {
    let id: String
    let type: String

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
       self.diaryNoteType = DiaryNoteItemType(rawValue: dictionary["diaryNoteType"] as? String ?? "")
       self.title = dictionary["title"] as? String
       self.body = dictionary["body"] as? String
       if let imageUrlString = dictionary["image"] as? String {
           self.image = URL(string: imageUrlString)
       } else {
           self.image = nil
       }
       self.urlString = dictionary["link_url"] as? String
    }
}

extension DiaryNoteItem: JSONAPIMappable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case diaryNoteType = "diaryNoteType"
        case title
        case body = "description"
        case image
        case urlString = "link_url"
    }
}
