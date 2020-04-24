//
//  ApiGateway.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import RxSwift
import Mapper

enum DefaultService {
    // Misc
    case getGlobalConfig
}

struct ApiRequest {
    
    let serviceRequest: DefaultService
    
    init(serviceRequest: DefaultService) {
        self.serviceRequest = serviceRequest
    }
}

enum ApiError: Error {
    
    case internalError
    case cannotParseData
    case network
    case connectivity
    case errorCode(Int, String)
    case error(Int, Any)
    case userUnauthorized
}

protocol ApiGateway {
    func send(request: ApiRequest) -> Single<Void>
    func send<T: Mappable>(request: ApiRequest) -> Single<T>
    func send<T: Mappable>(request: ApiRequest) -> Single<T?>
    func send<T: Mappable>(request: ApiRequest) -> Single<[T]>
    func sendExcludeInvalid<T: Mappable>(request: ApiRequest) -> Single<[T]>
    
    func send<E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<()>
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T>
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?>
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]>
    func sendExcludeInvalid<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]>
}
