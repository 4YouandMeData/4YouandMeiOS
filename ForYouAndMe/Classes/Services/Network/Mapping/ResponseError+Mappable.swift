//
//  ResponseError+Mappable.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/05/2020.
//

import Foundation
import Mapper

extension ResponseError: Mappable {
    init(map: Mapper) throws {
        try self.errors = map.from("errors")
    }
}

extension ServerError: Mappable {
    init(map: Mapper) throws {
        try self.statusCode = map.from("status")
    }
}
