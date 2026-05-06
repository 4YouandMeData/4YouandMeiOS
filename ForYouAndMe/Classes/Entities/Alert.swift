//
//  Alert.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/10/2020.
//

import Foundation

/// Layout variant for pinned feed alerts (FUAM-2932). The BE picks the
/// presentation: `compact` collapses image and vertical padding to a
/// shorter card, `standard` keeps the full hero-style layout.
enum AlertLayout: String, Decodable {
    case compact
    case standard
}

struct Alert {
    let id: String
    let type: String

    @NilIfEmptyString
    var title: String?
    @NilIfEmptyString
    var body: String?
    @URLDecodable
    var image: URL?
    @NilIfEmptyString
    var buttonText: String?
    @NilIfEmptyString
    var secondaryButtonText: String?
    @NilIfEmptyString
    var urlString: String?

    @ColorDecodable
    var startColor: UIColor?
    @ColorDecodable
    var endColor: UIColor?
    @ColorDecodable
    var cardColor: UIColor?

    var pinned: Bool?
    var layout: AlertLayout?
}

extension Alert: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body = "description"
        case image
        case buttonText = "task_action_button_label"
        case secondaryButtonText = "secondary_button_label"
        case urlString = "link_url"
        case startColor = "start_color"
        case endColor = "end_color"
        case cardColor = "card_color"
        case pinned
        case layout
    }
}

extension Alert {
    var isPinned: Bool { pinned ?? false }
    /// Resolved layout — defaults to `.standard` when the BE omits the field.
    var resolvedLayout: AlertLayout { layout ?? .standard }
}
