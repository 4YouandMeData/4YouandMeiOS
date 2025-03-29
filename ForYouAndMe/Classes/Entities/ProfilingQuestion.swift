//
//  ProfilingQuestion.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 27/03/25.
//

import Foundation

struct ProfilingQuestion: Decodable {
    let id: String
    let type: String
    let title: String
    let body: String
    
    @ImageDecodable
    var image: UIImage?
    
    @FailableDecodable
    var profilingOptions: [ProfilingOption]?
}

extension ProfilingQuestion: JSONAPIMappable {
    
    static var includeList: String? = """
profiling_options,\
body,\
title,\
image
"""
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case image
        case profilingOptions = "profiling_options"
    }
}

extension ProfilingQuestion: Hashable, Equatable {
    static func == (lhs: ProfilingQuestion, rhs: ProfilingQuestion) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    var isValid: Bool {
        guard let options = self.profilingOptions, options.count > 0 else { return false }
        return true
    }
}
