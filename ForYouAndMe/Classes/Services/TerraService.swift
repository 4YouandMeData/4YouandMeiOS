//
//  TerraService.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 20/06/25.
//

import Foundation
import TerraiOS
import RxSwift

protocol TerraService {
    func connectToTerraIfAvailable() -> Single<Void>
    func initialize() -> Single<Void>
}

struct TerraGenerateTokenResponse: Decodable {
    let token: String
}
