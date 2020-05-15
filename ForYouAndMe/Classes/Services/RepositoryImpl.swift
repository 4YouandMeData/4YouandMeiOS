//
//  RepositoryImpl.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

protocol RepositoryStorage {
    var globalConfig: GlobalConfig? { get set }
}

class RepositoryImpl {
    
    var isInitialized: Bool = false
    
    private var storage: RepositoryStorage
    
    private let api: ApiGateway
    
    init(api: ApiGateway,
         storage: RepositoryStorage) {
        self.api = api
        self.storage = storage
    }
    
    // MARK: - Private Methods
    
    private func fetchGlobalConfig() -> Single<()> {
        var cacheGlobalConfig = true
        #if DEBUG
        cacheGlobalConfig = false == Constants.Test.NoCacheGlobalConfig
        #endif
        let request: Single<GlobalConfig> = {
            if let storedItem = self.storage.globalConfig, cacheGlobalConfig {
                return Single.just(storedItem)
            } else {
                return self.api.send(request: ApiRequest(serviceRequest: .getGlobalConfig))
                    .do(onSuccess: { self.storage.globalConfig = $0 })
                    .handleError()
            }
        }()
        return request
            .do(onSuccess: { (globalCongig: GlobalConfig) in
                ColorPalette.initialize(withColorMap: globalCongig.colorMap)
                StringsProvider.initialize(withStringMap: globalCongig.stringMap)
            })
            .map { _ in () }
    }
}

// MARK: - Repository

extension RepositoryImpl: Repository {
    // MARK: - Authentication
    
    var isLoggedIn: Bool {
        // TODO: Implement login check
        return false
    }
    
    func submitPhoneNumber(phoneNumber: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .submitPhoneNumber(phoneNumber: phoneNumber)))
        .handleError()
        .catchError({ error -> Single<()> in
            enum ErrorCode: Int, CaseIterable { case missingPhoneNumber = 404 }
            if let errorCodeNumber = error.getFirstServerError(forExpectedStatusCodes: ErrorCode.allCases.map{ $0.rawValue }),
                let errorCode = ErrorCode(rawValue: errorCodeNumber) {
                switch errorCode {
                case .missingPhoneNumber: return Single.error(RepositoryError.missingPhoneNumber)
                }
            } else {
                return Single.error(error)
            }
        })
    }
    
    func verifyPhoneNumber(phoneNumber: String, secureCode: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .verifyPhoneNumber(phoneNumber: phoneNumber,
                                                                                    secureCode: secureCode)))
        .handleError()
        .catchError({ error -> Single<()> in
            enum ErrorCode: Int, CaseIterable { case wrongValidationCode = 403 }
            if let errorCodeNumber = error.getFirstServerError(forExpectedStatusCodes: ErrorCode.allCases.map{ $0.rawValue }),
                let errorCode = ErrorCode(rawValue: errorCodeNumber) {
                switch errorCode {
                case .wrongValidationCode: return Single.error(RepositoryError.wrongValidationCode)
                }
            } else {
                return Single.error(error)
            }
        })
    }
}

// MARK: - Extension(PrimitiveSequence)

fileprivate extension PrimitiveSequence where Trait == SingleTrait {
    func handleError() -> Single<Element> {
        return self.handleNetworkError()
    }
    
    func handleNetworkError() -> Single<Element> {
        return self.catchError({ (error) -> Single<Element> in
            if let error = error as? ApiError {
                switch error {
                case .internalError: return Single.error(RepositoryError.genericError)
                case .cannotParseData: return Single.error(RepositoryError.remoteServerError)
                case .network: return Single.error(RepositoryError.remoteServerError)
                case .connectivity: return Single.error(RepositoryError.connectivityError)
                case .errorCode: return Single.error(RepositoryError.remoteServerError)
                case let .error(_, error): return Single.error(RepositoryError.serverErrorSpecific(error: error))
                case .userUnauthorized: return Single.error(RepositoryError.userNotLoggedIn)
                }
            }
            return Single.error(error)
        })
    }
}

// MARK: - InitializableService

extension RepositoryImpl: InitializableService {
    func initialize() -> Single<()> {
        return self.fetchGlobalConfig()
            .do(onSuccess: { self.isInitialized = true })
    }
}

// MARK: - Extension (Error)

fileprivate extension Error {
    func getFirstServerError(forExpectedStatusCodes statusCodes: [Int]) -> Int? {
        if let repositoryError = self as? RepositoryError {
            switch repositoryError {
            case let .serverErrorSpecific(error):
                if let error = error as? ResponseError {
                    return error.getFirstErrorMatching(errorCodes: statusCodes)
                }
            default: return nil
            }
        }
        return nil
    }
}
