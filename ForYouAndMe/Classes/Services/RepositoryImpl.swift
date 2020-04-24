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
//    var globalConfig: GlobalConfig? { get set }
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
        // TODO: Fetch Global Config
        return Single.just(())
    }
}

// MARK: - Repository

extension RepositoryImpl: Repository {
    // MARK: - Authentication
    
    var isLoggedIn: Bool {
        // TODO: Implement login check
        return false
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
                case .error: return Single.error(RepositoryError.remoteServerError)
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
