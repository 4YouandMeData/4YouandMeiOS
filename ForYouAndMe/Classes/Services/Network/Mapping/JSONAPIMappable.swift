//
//  JSONAPIMappable.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/05/2020.
//

import Foundation
import Japx

protocol JSONAPIMappable: JapxDecodable {
    static var includeList: String? { get }
    static var keyPath: String? { get }
}

extension JSONAPIMappable {
    static var includeList: String? { nil }
    static var keyPath: String? { "data" }
}
