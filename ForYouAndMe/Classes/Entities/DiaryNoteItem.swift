//
//  DiaryNoteItem.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import Foundation

typealias DiaryNoteData = [String: Any]

public enum DiaryNotePayload {
    case food(mealType: String, quantity: String, significantNutrition: Bool)
    case doses(quantity: Int, doseType: String)
    case noticed(
        physicalActivity: String,
        oldValue: Double,
        currentValue: Double,
        oldValueRetrievedAt: Date,
        currentValueRetrievedAt: Date,
        stressLevel: String,
        // Optional injection and eating details
        injected: Bool?,
        injectionType: String?,
        injectionQuantity: Int?,
        ateInPriorHour: Bool?,
        ateType: String?,
        ateDate: Date?,
        ateQuantity: String?,
        ateFat: Bool?
    )
}

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let dateVal = try? container.decode(Date.self) {
            value = dateVal
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let dateVal as Date:
            try container.encode(dateVal)
        default:
            throw EncodingError.invalidValue(value,
                EncodingError.Context(codingPath: encoder.codingPath,
                                      debugDescription: "Unsupported type"))
        }
    }
}

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
    let answeredActivity: ActivityLevel?
    let answeredStress: StressLevel?
    
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
    
    var payload: DiaryNotePayload?
    
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
        case rawData = "data"
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
        var payload: DiaryNotePayload?
        // Decode payload
        if let raw = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .rawData),
           let noteType = diaryNoteType {
            let isoFmt = ISO8601DateFormatter()
            switch noteType {
            case .eaten:
                let meal = raw["meal_type"]?.value as? String ?? ""
                let qty  = raw["quantity"]?.value as? String ?? raw["food_quantity"]?.value as? String ?? ""
                let fat  = raw["with_significant_protein_fiber_or_fat"]?.value as? Bool ?? false
                payload = .food(mealType: meal, quantity: qty, significantNutrition: fat)
                
            case .doses:
                let qty = (raw["quantity"]?.value as? Int)
                ?? (raw["quantity"]?.value as? Double).flatMap { Int($0) }
                ?? 0
                let dt  = raw["dose_type"]?.value as? String ?? ""
                payload = .doses(quantity: qty, doseType: dt)
                
            case .weNoticed:
                // Required fields
                let pa = raw["physical_activity"]?.value as? String ?? ""
                let ov: Double = (raw["old_value"]?.value as? Double)
                ?? (raw["old_value"]?.value as? Int).map(Double.init)
                ?? 0
                let cv: Double = (raw["current_value"]?.value as? Double)
                ?? (raw["current_value"]?.value as? Int).map(Double.init)
                ?? 0
                // Parse timestamps
                let ovd: Date = {
                    if let sx = raw["old_value_retrieved_at"]?.value as? String,
                       let dx = isoFmt.date(from: sx) { return dx }
                    return Date()
                }()
                let cvd: Date = {
                    if let sx = raw["current_value_retrieved_at"]?.value as? String,
                       let dx = isoFmt.date(from: sx) { return dx }
                    return Date()
                }()
                let sl = raw["stress_level"]?.value as? String ?? ""
                // Optional injection
                let injType = raw["dose_type"]?.value as? String
                let injQty  = (raw["quantity"]?.value as? Int)
                ?? (raw["quantity"]?.value as? Double).flatMap { Int($0) }
                let injFlag: Bool? = raw["dose_type"] != nil ? true : nil
                // Optional eating
                let ateFlag: Bool? = raw["meal_type"] != nil ? true : nil
                let ateType: String? = raw["meal_type"]?.value as? String
                let ateDt: Date? = (raw["current_value_retrieved_at"]?.value as? String).flatMap { isoFmt.date(from: $0) }
                let ateQty: String? = raw["food_quantity"]?.value as? String
                let ateFat: Bool? = raw["with_significant_protein_fiber_or_fat"]?.value as? Bool ?? false
                
                payload = .noticed(
                    physicalActivity: pa,
                    oldValue: ov,
                    currentValue: cv,
                    oldValueRetrievedAt: ovd,
                    currentValueRetrievedAt: cvd,
                    stressLevel: sl,
                    injected: injFlag,
                    injectionType: injType,
                    injectionQuantity: injQty,
                    ateInPriorHour: ateFlag,
                    ateType: ateType,
                    ateDate: ateDt,
                    ateQuantity: ateQty,
                    ateFat: ateFat
                )
                
            default:
                break
            }
        }
        self.payload = payload
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
