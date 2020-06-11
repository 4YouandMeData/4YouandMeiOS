//
//  InfoPage.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

struct InfoPage {
    let id: String
    let type: String

    let title: String
    let body: String
    @NilIfEmptyString
    var externalLinkLabel: String?
    @FailableDecodable
    var externalLinkUrl: URL?
    let imageData: Data
    @NilIfEmptyString
    var buttonFirstlabel: String?
    var buttonFirstPage: InfoPageRef?
    @NilIfEmptyString
    var buttonSecondlabel: String?
    var buttonSecondPage: InfoPageRef?
}

extension InfoPage: JSONAPIMappable {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case externalLinkLabel = "external_link_label"
        case externalLinkUrl = "external_link_url"
        case buttonFirstlabel = "link_1_label"
        case buttonFirstPage = "link_1"
        case buttonSecondlabel = "link_2_label"
        case buttonSecondPage = "link_2"
        case imageData = "image"
    }
}

extension InfoPage {
    var image: UIImage? { return UIImage(data: self.imageData) }
}

extension Array where Element == InfoPage {
    func getFirstNextPage(forPageRef pageRef: InfoPageRef) -> InfoPage? {
        return self.first(where: { $0.id == pageRef.id })
    }
}
