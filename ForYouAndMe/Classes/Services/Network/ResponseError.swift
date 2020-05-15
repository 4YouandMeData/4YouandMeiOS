//
//  ResponseError.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/05/2020.
//

import Foundation

struct ResponseError {
    let errors: [ServerError]
}

struct ServerError {
    let statusCode: Int
}

extension ResponseError {
    func getFirstErrorMatching(errorCodes: [Int]) -> Int? {
        return self.errors.first { errorCodes.contains($0.statusCode) }?.statusCode
    }
}
