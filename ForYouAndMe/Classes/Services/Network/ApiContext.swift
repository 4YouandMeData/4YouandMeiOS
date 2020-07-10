//
//  ApiContext.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 10/07/2020.
//

import Foundation

struct ApiContext {
    
    private let date: Date
    
    var batchIdentifier: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter.string(from: self.date)
    }
    
    init() {
        self.date = Date()
    }
}
