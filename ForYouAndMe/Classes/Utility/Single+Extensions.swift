//
//  Single+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 01/10/2020.
//

import Foundation
import RxSwift

public extension PrimitiveSequence where Trait == SingleTrait {
    func toVoid() -> Single<Void> {
        return self.map { _ in () }
    }
}
