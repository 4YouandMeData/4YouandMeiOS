//
//  KpiWidget.swift
//  ForYouAndMe
//
//  FUAM-4315: a backend-computed KPI shown as a card at the top of the Feed.
//  The client only draws it: numbers, threshold check, title and body all come from the API.
//

import UIKit

struct KpiWidget: Codable, Equatable {
    static let supportedKpiType = "quick_activities_adherence"

    let id: String
    let type: String

    let kpiType: String
    let displayMode: String
    let position: Int?
    let featured: Bool
    let completed: Int
    let total: Int
    let percentage: Double?
    let meetsThreshold: Bool
    let title: String?
    let body: String?

    /// The integer shown in the gauge: `min(100, floor(percentage))`, 0 when nothing is settled (D6).
    var displayPercent: Int {
        guard let percentage = self.percentage else { return 0 }
        return Int(min(100, max(0, percentage.rounded(.down))))
    }

    /// The gauge fill in 0...1 (D6). Clamped defensively: the backend formula cannot exceed 100 %.
    var fill: CGFloat {
        guard let percentage = self.percentage else { return 0 }
        return CGFloat(min(1, max(0, percentage / 100)))
    }

    /// Only the Quick Activities adherence KPI is rendered in v1 (D8).
    var isSupported: Bool { self.kpiType == Self.supportedKpiType }
}

extension KpiWidget: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case kpiType = "kpi_type"
        case displayMode = "display_mode"
        case position
        case featured
        case completed
        case total
        case percentage
        case meetsThreshold = "meets_threshold"
        case title
        case body
    }

    // The admin form posts "" for a cleared field: a blank title, or a body with no visible
    // text once scanned (e.g. "<p></p>\n"), is treated as absent (same rule as Android).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.type = try container.decode(String.self, forKey: .type)
        self.kpiType = try container.decode(String.self, forKey: .kpiType)
        self.displayMode = try container.decode(String.self, forKey: .displayMode)
        self.position = try container.decodeIfPresent(Int.self, forKey: .position)
        self.featured = try container.decode(Bool.self, forKey: .featured)
        self.completed = try container.decode(Int.self, forKey: .completed)
        self.total = try container.decode(Int.self, forKey: .total)
        self.percentage = try container.decodeIfPresent(Double.self, forKey: .percentage)
        self.meetsThreshold = try container.decode(Bool.self, forKey: .meetsThreshold)
        let title = try container.decodeIfPresent(String.self, forKey: .title)
        self.title = title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title : nil
        let body = try container.decodeIfPresent(String.self, forKey: .body)
        self.body = body.map { KpiHtmlScanner.scan($0).isEmpty } == false ? body : nil
    }
}

enum KpiWidgetError: Error {
    /// HTTP 404 from /kpi_widgets: the backend does not have the endpoint (FUAM-4314 not deployed).
    case endpointNotFound
}

enum KpiWidgetState: Equatable {
    /// Nothing confirmed in this process yet (cold start, failed cold start, after logout).
    case idle
    /// The API answered; an empty list means the study has no widget and nothing is rendered.
    case loaded([KpiWidget])

    var widgets: [KpiWidget] {
        if case .loaded(let widgets) = self { return widgets }
        return []
    }
}
