//
//  InfoPage.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

enum PageSpecialLinkType: String, Decodable {
    case app = "App"
}

struct Page {
    let id: String
    let type: String

    let title: String
    let body: String
    @NilIfEmptyString
    var externalLinkLabel: String?
    @FailableDecodable
    var externalLinkUrl: URL?
    @NilIfEmptyString
    var specialLinkLabel: String?
    @FailableDecodable
    var specialLinkValue: URL?
    @FailableDecodable
    var specialLinkType: PageSpecialLinkType?
    let imageData: Data?
    @NilIfEmptyString
    var buttonFirstlabel: String?
    var buttonFirstPage: PageRef?
    @NilIfEmptyString
    var buttonSecondlabel: String?
    var buttonSecondPage: PageRef?
}

extension Page: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case externalLinkLabel = "external_link_label"
        case externalLinkUrl = "external_link_url"
        case specialLinkLabel = "special_link_label"
        case specialLinkValue = "special_link_value"
        case specialLinkType = "special_link_type"
        case buttonFirstlabel = "link_1_label"
        case buttonFirstPage = "link_1"
        case buttonSecondlabel = "link_2_label"
        case buttonSecondPage = "link_2"
        case imageData = "image"
    }
}

extension Page {
    var image: UIImage? {
        if let data = self.imageData {
            return UIImage(data: data)
        } else {
            return nil
        }
    }
}

extension Array where Element == Page {
    func getPage(forPageRef pageRef: PageRef) -> Page? {
        return self.first(where: { $0.id == pageRef.id })
    }
}
