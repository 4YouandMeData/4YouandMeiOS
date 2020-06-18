//
//  InfoPageRef.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import Foundation

struct InfoPageRef {
    let id: String
    let type: String
}

extension InfoPageRef: JSONAPIMappable {}

extension InfoPageRef {
    func getInfoPage(fromInfoPages infoPages: [InfoPage]) -> InfoPage? {
        return infoPages.getInfoPage(forInfoPageRef: self)
    }
}
