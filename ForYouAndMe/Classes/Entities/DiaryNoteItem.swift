//
//  DiaryNoteItem.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 02/12/24.
//

import Foundation

typealias DiaryNoteData = [String: Any]

extension EmojiItem: JSONAPIMappable {

    static var includeList: String? = """
feedback_tag
"""
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case tag
        case label
    }
}

public enum DiaryNotePayload {
    case food(mealType: String, quantity: String, significantNutrition: Bool, canSpecifyCalories: Bool?, caloriesValue: Int?, carbsGrams: Int?)
    case doses(quantity: Int, doseType: String)
    case hotFlash(date: Date)
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
    case menstrual(
        date: Date,
        flowAmount: String,
        periodRelated: String,
        bleeding: String,
        note: String?
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
    case hotFlash = "hot_flash_diary"
    case menstrualPeriod = "menstrual_period"
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

struct DiaryNoteEatenData {
    let date: Date
    let mealType: String
    let quantity: String
    let significantNutrition: Bool
    let canSpecifyCalories: Bool?
    let caloriesValue: Int?
    let carbsGrams: Int?
    let fromChart: Bool
    let diaryNote: DiaryNoteItem?
}

struct DiaryNoteHotFlashData {
    let date: Date
    let fromChart: Bool
    let diaryNote: DiaryNoteItem?
}

enum MenstrualBleeding: String {
    case yes
    case no
    case other
}

/// FUAM-2934 — Server-side menstrual series grouping (BE v0.12.5). Present on
/// the compressed `/diary_notes` index row (the last `yes` day of a series)
/// and on `GET /diary_notes/:id` when the requested id is that last `yes`.
/// `nil` for every other row (closing `no`, orphan `other`, non-menstrual).
struct MenstrualSeriesMeta: Codable {
    /// First `yes` day of the series.
    let from: Date
    /// Last `yes` day; `nil` while the series is still ongoing.
    let to: Date?
    /// `true` while no closing `no` day exists yet.
    let ongoing: Bool
    /// Total members (yes + other); excludes the closing `no`.
    let count: Int

    enum CodingKeys: String, CodingKey {
        case from, to, ongoing, count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let formatter = MenstrualSeriesMeta.dateFormatter
        let fromString = try container.decode(String.self, forKey: .from)
        guard let fromDate = formatter.date(from: fromString) else {
            throw DecodingError.dataCorruptedError(forKey: .from, in: container,
                                                   debugDescription: "Invalid date: \(fromString)")
        }
        self.from = fromDate
        if let toString = try container.decodeIfPresent(String.self, forKey: .to) {
            self.to = formatter.date(from: toString)
        } else {
            self.to = nil
        }
        self.ongoing = try container.decode(Bool.self, forKey: .ongoing)
        self.count = try container.decode(Int.self, forKey: .count)
    }

    /// BE serializes the series bounds as date-only `YYYY-MM-DD` strings.
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum MenstrualFlowAmount: String, CaseIterable {
    case spotting
    case light
    case moderate
    case heavy
    case veryHeavy = "very_heavy"

    var iconName: TemplateImageName {
        switch self {
        case .spotting:  return .menstrualFlowSpotting
        case .light:     return .menstrualFlowLight
        case .moderate:  return .menstrualFlowModerate
        case .heavy:     return .menstrualFlowHeavy
        case .veryHeavy: return .menstrualFlowVeryHeavy
        }
    }

    /// Backend `flow` value (FUAM-2925 schema: integer 0–4).
    var intValue: Int {
        switch self {
        case .spotting:  return 0
        case .light:     return 1
        case .moderate:  return 2
        case .heavy:     return 3
        case .veryHeavy: return 4
        }
    }

    init?(intValue: Int) {
        switch intValue {
        case 0: self = .spotting
        case 1: self = .light
        case 2: self = .moderate
        case 3: self = .heavy
        case 4: self = .veryHeavy
        default: return nil
        }
    }
}

enum MenstrualPeriodRelated: String, CaseIterable {
    case yes
    case no
    case notSure = "not_sure"
    case letMeExplain = "let_me_explain"

    var bleeding: MenstrualBleeding {
        // Wizard semantics: only the "yes" answer reports actual bleeding.
        // "no", "not sure", and "let me explain" all collapse to bleeding=other
        // — the user's specific choice survives via `period_related`. The
        // bleeding="no" value is reserved for the FUAM-2932 feed-alert "No"
        // shortcut, which bypasses the wizard entirely.
        switch self {
        case .yes: return .yes
        case .no, .notSure, .letMeExplain: return .other
        }
    }

    /// Backend `period_related` value (FUAM-2925 schema: yes/no/not_sure/other).
    /// `letMeExplain` collapses to `other` — the explanation rides in `note`.
    var backendValue: String {
        switch self {
        case .yes: return "yes"
        case .no: return "no"
        case .notSure: return "not_sure"
        case .letMeExplain: return "other"
        }
    }

    /// Decode the BE `period_related` value back into the wizard enum.
    /// Inverse of `backendValue`: maps `"other"` to `.letMeExplain` since
    /// that's the only branch that produces "other" on send.
    init?(backendValue: String) {
        switch backendValue {
        case "yes":            self = .yes
        case "no":             self = .no
        case "not_sure":       self = .notSure
        case "other",
             "let_me_explain": self = .letMeExplain
        default: return nil
        }
    }
}

struct DiaryNoteMenstrualData {
    let date: Date
    let bleeding: MenstrualBleeding
    let flowAmount: MenstrualFlowAmount?
    let periodRelated: MenstrualPeriodRelated?
    /// Free-form text shown when the user taps "Let me explain" on step 4.
    /// Captured before the final note step so the two inputs stay separate.
    let periodRelatedExplanation: String?
    let note: String?
    let fromChart: Bool
    let diaryNote: DiaryNoteItem?

    /// Wizard path (FUAM-2935): bleeding is derived from `periodRelated`.
    init(date: Date,
         flowAmount: MenstrualFlowAmount,
         periodRelated: MenstrualPeriodRelated,
         periodRelatedExplanation: String?,
         note: String?,
         fromChart: Bool,
         diaryNote: DiaryNoteItem?) {
        self.date = date
        self.bleeding = periodRelated.bleeding
        self.flowAmount = flowAmount
        self.periodRelated = periodRelated
        self.periodRelatedExplanation = periodRelatedExplanation
        self.note = note
        self.fromChart = fromChart
        self.diaryNote = diaryNote
    }

    /// FUAM-2932 feed-alert "No" path: bleeding-only entry. Skips flow,
    /// period_related, and note so the BE only persists `bleeding`.
    init(date: Date,
         bleeding: MenstrualBleeding,
         fromChart: Bool,
         diaryNote: DiaryNoteItem?) {
        self.date = date
        self.bleeding = bleeding
        self.flowAmount = nil
        self.periodRelated = nil
        self.periodRelatedExplanation = nil
        self.note = nil
        self.fromChart = fromChart
        self.diaryNote = diaryNote
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

    var feedbackTags: [EmojiItem]?

    /// FUAM-2934 — BE v0.12.5 series metadata; non-nil only on the compressed
    /// menstrual row / on the show response for the last `yes` of a series.
    var seriesMeta: MenstrualSeriesMeta?

    /// FUAM-2934 — All members of the series (yes + other, chronological,
    /// excluding the closing `no`), sideloaded by `GET /diary_notes/:id`.
    /// Empty/nil on the index and on non-anchor rows.
    var seriesEntries: [DiaryNoteItem]?

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
diary_noteable,\
feedback_tags,\
series_entries,\
series_entries.feedback_tags
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
        case feedbackTags = "feedback_tags"
        case seriesMeta = "series_meta"
        case seriesEntries = "series_entries"
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

        self.feedbackTags = try? container.decodeIfPresent(Array<EmojiItem>.self, forKey: .feedbackTags)

        // FUAM-2934: BE v0.12.5 series grouping — both optional / additive.
        self.seriesMeta = try? container.decodeIfPresent(MenstrualSeriesMeta.self, forKey: .seriesMeta)
        self.seriesEntries = try? container.decodeIfPresent(Array<DiaryNoteItem>.self, forKey: .seriesEntries)

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
                let canSpecify = raw["can_specify_calories"]?.value as? Bool
                let calories = (raw["calories"]?.value as? Int)
                ?? (raw["calories"]?.value as? Double).flatMap { Int($0) }
                let carbs = (raw["carbs_grams"]?.value as? Int)
                ?? (raw["carbs_grams"]?.value as? Double).flatMap { Int($0) }
                payload = .food(mealType: meal, quantity: qty, significantNutrition: fat, canSpecifyCalories: canSpecify, caloriesValue: calories, carbsGrams: carbs)
                
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

            case .hotFlash:
                let date: Date = {
                    if let sx = raw["datetime_ref"]?.value as? String,
                       let dx = isoFmt.date(from: sx) { return dx }
                    return self.diaryNoteId
                }()
                payload = .hotFlash(date: date)

            case .menstrualPeriod:
                let dateStr = raw["date"]?.value as? String
                // BE v0.12.5 sends `data.date` as a calendar day (YYYY-MM-DD);
                // older payloads used a full ISO8601 timestamp. Try both, then
                // fall back to datetime_ref.
                let date: Date = dateStr.flatMap {
                    MenstrualSeriesMeta.dateFormatter.date(from: $0) ?? isoFmt.date(from: $0)
                } ?? self.diaryNoteId
                // FUAM-2925: BE stores flow as integer 0..4. Map it back to the
                // MenstrualFlowAmount.rawValue string the UI consumers expect.
                let flowInt: Int? = (raw["flow"]?.value as? Int)
                    ?? (raw["flow"]?.value as? Double).flatMap { Int($0) }
                let flow = flowInt.flatMap { MenstrualFlowAmount(intValue: $0)?.rawValue } ?? ""
                let related = raw["period_related"]?.value as? String ?? ""
                let bleeding = raw["bleeding"]?.value as? String ?? ""
                let note = raw["note"]?.value as? String
                payload = .menstrual(
                    date: date,
                    flowAmount: flow,
                    periodRelated: related,
                    bleeding: bleeding,
                    note: note
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

struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
