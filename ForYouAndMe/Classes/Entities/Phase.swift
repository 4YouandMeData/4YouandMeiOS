//
//  Phase.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/03/23.
//

import Foundation

typealias PhaseIndex = Int

struct Phase: Codable {
    let id: String
    let type: String
    let name: String
    let faqPage: Page?
}

extension Phase: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case faqPage = "faq_page"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.name, forKey: .name)
    }
}

extension Array where Element == Phase {
    func getPhase(withName name: String) -> Phase? {
        self.first(where: { $0.name == name })
    }
}

struct UserPhase: Codable {
    let id: String
    let type: String
    @FailableDateValue<ISO8601Strategy>
    var startAt: Date?
    @FailableDateValue<ISO8601Strategy>
    var endAt: Date?
    var phase: Phase
}

extension UserPhase: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case startAt = "start_at"
        case endAt = "end_at"
        case phase = "study_phase"
    }
}

extension Array where Element == UserPhase {
    func sort(byNames names: [String]) -> [UserPhase] {
        self.sorted { userPhase1, userPhase2 in
            names.firstIndex(of: userPhase1.phase.name) ?? 0 < names.firstIndex(of: userPhase2.phase.name) ?? 0
        }
    }
}
