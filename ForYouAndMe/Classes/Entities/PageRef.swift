//
//  PageRef.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import Foundation

struct PageRef {
    let id: String
    let type: String
}

extension PageRef: JSONAPIMappable {}

extension PageRef {
    func getPage(fromPages pages: [Page]) -> Page? {
        return pages.getPage(forPageRef: self)
    }
}
