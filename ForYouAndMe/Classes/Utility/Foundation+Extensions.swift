//
//  Foundation+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/09/2020.
//

import Foundation

public extension Array where Element: Equatable {
    
    func randomItem() -> Element {
        let index = Int(UInt32(arc4random_uniform(UInt32(self.count))))
        return self[index]
    }
    
    func takeElements(_ elementCount: Int) -> Array {
        if elementCount > count {
            return Array(self[0..<count])
        }
        return Array(self[0..<elementCount])
    }
    
    mutating func removeObject(_ object: Element) {
        if let index = firstIndex(of: object) {
            remove(at: index)
        }
    }
}

public extension Array where Element: Hashable {
    
    var toSet: Set<Element> {
        return Set(self)
    }
}
