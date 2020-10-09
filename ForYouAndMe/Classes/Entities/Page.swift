//
//  InfoPage.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

enum PageSpecialLinkType: String, Decodable {
    case app
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
    var linkModalLabel: String?
    var linkModalPage: PageRef?
    @NilIfEmptyString
    var specialLinkLabel: String?
    @NilIfEmptyString
    var specialLinkValue: String?
    @FailableDecodable
    var specialLinkType: PageSpecialLinkType?
    @ImageDecodable
    var image: UIImage?
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
        case linkModalLabel = "link_modal_label"
        case linkModalPage = "link_modal"
        case specialLinkLabel = "special_link_label"
        case specialLinkValue = "special_link_data"
        case specialLinkType = "special_link_type"
        case buttonFirstlabel = "link_1_label"
        case buttonFirstPage = "link_1"
        case buttonSecondlabel = "link_2_label"
        case buttonSecondPage = "link_2"
        case image = "image"
    }
}

extension Page {
    init(id: String, title: String, body: String) {
        self.init(id: id, image: nil, title: title, body: body, buttonFirstLabel: nil, buttonSecondLabel: nil)
    }
    
    init(id: String, image: UIImage?, title: String, body: String, buttonFirstLabel: String?, buttonSecondLabel: String?) {
        self.id = id
        self.type = "page"
        self.title = title
        self.body = body
        self.externalLinkLabel = nil
        self.externalLinkUrl = nil
        self.linkModalLabel = nil
        self.linkModalPage = nil
        self.specialLinkLabel = nil
        self.specialLinkValue = nil
        self.specialLinkType = nil
        self.image = image
        self.buttonFirstlabel = buttonFirstLabel
        self.buttonFirstPage = nil
        self.buttonSecondlabel = buttonSecondLabel
        self.buttonSecondPage = nil
    }
}

extension Array where Element == Page {
    func getPage(forPageRef pageRef: PageRef) -> Page? {
        return self.first(where: { $0.id == pageRef.id })
    }
}
