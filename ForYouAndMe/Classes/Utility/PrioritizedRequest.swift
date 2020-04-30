//
//  PrioritizedRequest.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import RxSwift

struct PrioritizedRequest {
    let hasPriority: Bool
    let disposable: Disposable
}
