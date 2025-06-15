//
//  DiaryNoteItem.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import Foundation

typealias DiaryNoteData = [String: Any]

enum TranscribeStatus: String, Codable {
    case pending
    case success
    case error
}

struct DiaryNoteFile {
    let data: Data
    let fileExtension: FileDataExtension
}

enum DiaryNoteItemType: String, Codable {
    case text = "note_diary"
    case audio
    case video
    case eaten = "food_diary"
    case doses = "insulin_diary"
    case weNoticed = "we_have_noticed"
}

enum DiaryNoteableType: String, Codable {
    case chart
    case task
    case none
}

struct DiaryNoteable: Codable {
    let id: String
    let type: String
}

extension DiaryNoteable: JSONAPIMappable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
    }
}

struct DiaryNoteWeHaveNoticedItem: Codable {
    
    let diaryType: DiaryNoteItemType
    let dosesData: DoseEntryData?
    let foodData: FoodEntryData?
    let diaryDate: Date
    let answeredActivity: PhysicalActivityViewController.ActivityLevel?
    let answeredStress: StressLevelViewController.StressLevel?
    
    let oldValue: Double
    
    @DateValue<ISO8601Strategy>
    var oldValueRetrievedAt: Date
    
    let currentValue: Double
    
    @DateValue<ISO8601Strategy>
    var currentValueRetrievedAt: Date
}

struct DiaryNoteItem: Codable {
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

    @NilIfEmptyString
    var urlString: String?
    
    @NilIfEmptyString
    var interval: String?
    
    @FailableCodable
    var transcribeStatus: TranscribeStatus?
    
    @FailableCodable
    var diaryNoteable: DiaryNoteable?
    
    init (id: String,
          type: String,
          diaryNoteId: Date,
          diaryNoteType: DiaryNoteItemType,
          title: String?,
          body: String?,
          interval: String?) {
        
        self.id = id
        self.type = type
        self.diaryNoteId = diaryNoteId
        self.diaryNoteType = diaryNoteType
        self.title = title
        self.body = body
    }
    
    init(diaryNoteId: String?,
         body: String?,
         interval: String?,
         diaryNoteable: DiaryNoteable?) {
        
        self.id = UUID().uuidString
        self.type = "diary_note"
        self.diaryNoteId = diaryNoteId?.date(withFormat: dateDataPointFormat) ?? Date()
        self.body = body
        self.interval = interval
        self.diaryNoteable = diaryNoteable
    }
}

extension DiaryNoteItem: JSONAPIMappable {
    
    static var includeList: String? = """
diary_noteable
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case diaryNoteId = "datetime_ref"
        case title
        case body
        case urlString = "attachment"
        case diaryNoteable = "diary_noteable"
        case transcribeStatus = "transcribe_status"
        case diaryNoteType = "diary_type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.diaryNoteId = try container.decode(DateValue<ISO8601Strategy>.self, forKey: .diaryNoteId).wrappedValue
        
        // Decode optional fields
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.body = try container.decodeIfPresent(String.self, forKey: .body)
        self.diaryNoteable = try container.decodeIfPresent(DiaryNoteable.self, forKey: .diaryNoteable)
        self.diaryNoteType = try? container.decodeIfPresent(DiaryNoteItemType.self, forKey: .diaryNoteType)
        
        if let attachmentContainer = try? container.decodeIfPresent([String: String].self, forKey: .urlString),
           let attachmentURL = attachmentContainer["url"] {
            self.urlString = attachmentURL
            if let contentType = attachmentContainer["content_type"] {
                if contentType.hasPrefix("video/") {
                    self.diaryNoteType = .video
                } else if contentType.hasPrefix("audio/") {
                    self.diaryNoteType = .audio
                }
            }
        }
        
        self.transcribeStatus = try? container.decodeIfPresent(TranscribeStatus.self, forKey: .transcribeStatus)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let formattedDate = diaryNoteId.string(withFormat: dateTimeFormat)
        try container.encode(formattedDate, forKey: .diaryNoteId)
        
        // Encode optional fields
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(urlString, forKey: .urlString)
        try container.encodeIfPresent(diaryNoteable, forKey: .diaryNoteable)
    }
}
