//
//  Page.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

struct Page {
    let id: String
    let type: String

    let title: String
    let body: String
    let externalLinkLabel: String?
    @FailableDecodable
    var externalLinkUrl: URL?
    let image: Data
}

extension Page: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case externalLinkLabel = "external_link_label"
        case externalLinkUrl = "external_link_url"
        case image
    }
}
