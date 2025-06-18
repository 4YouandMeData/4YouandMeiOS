//
//  String+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 17/03/21.
//

import Foundation

extension String {
    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self,
                                        range: NSRange(self.startIndex..., in: self))
            return results.compactMap {
                guard let range = Range($0.range, in: self) else {
                    return nil
                }
                return String(self[range])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    func replacingPlaceholders(with args: [String]) -> String {
        var result = self
        for (idx, arg) in args.enumerated() {
            result = result.replacingOccurrences(of: "{\(idx)}", with: arg)
        }
        return result
    }
}
