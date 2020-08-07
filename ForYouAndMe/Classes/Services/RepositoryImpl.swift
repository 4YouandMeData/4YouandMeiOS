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
        let request: Single<GlobalConfig> = {
            if let storedItem = self.storage.globalConfig, Constants.Misc.EnableGlobalConfigCache {
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
                CountryCodeProvider.initialize(withcountryCodes: globalCongig.countryCodes)
            })
            .map { _ in () }
    }
}

// MARK: - Repository

extension RepositoryImpl: Repository {
    // MARK: - Authentication
    
    var accessToken: String? {
        self.api.accessToken
    }
    
    var isLoggedIn: Bool {
        return self.api.isLoggedIn()
    }
    
    func logOut() {
        self.api.logOut()
    }
    
    func submitPhoneNumber(phoneNumber: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .submitPhoneNumber(phoneNumber: phoneNumber)))
            .handleError()
            .catchError({ error -> Single<()> in
                enum ErrorCode: Int, CaseIterable { case missingPhoneNumber = 404 }
                if let errorCodeNumber = error.getFirstServerError(forExpectedStatusCodes: ErrorCode.allCases.map { $0.rawValue }),
                    let errorCode = ErrorCode(rawValue: errorCodeNumber) {
                    switch errorCode {
                    case .missingPhoneNumber: return Single.error(RepositoryError.missingPhoneNumber)
                    }
                } else {
                    return Single.error(error)
                }
            })
    }
    
    func verifyPhoneNumber(phoneNumber: String, validationCode: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .verifyPhoneNumber(phoneNumber: phoneNumber,
                                                                                    validationCode: validationCode)))
            .handleError()
            .catchError({ error -> Single<()> in
                enum ErrorCode: Int, CaseIterable { case wrongValidationCode = 401 }
                if let errorCodeNumber = error.getFirstServerError(forExpectedStatusCodes: ErrorCode.allCases.map { $0.rawValue }),
                    let errorCode = ErrorCode(rawValue: errorCodeNumber) {
                    switch errorCode {
                    case .wrongValidationCode: return Single.error(RepositoryError.wrongPhoneValidationCode)
                    }
                } else {
                    return Single.error(error)
                }
            })
    }
    
    // MARK: - Screening
    
    func getScreeningSection() -> Single<ScreeningSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getScreeningSection))
            .handleError()
    }
    
    // MARK: - Informed Consent
    
    func getInformedConsentSection() -> Single<InformedConsentSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getInformedConsentSection))
            .handleError()
    }
    
    // MARK: - Consent
    
    func getConsentSection() -> Single<ConsentSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getConsentSection))
            .handleError()
    }
    
    // MARK: - Opt In
    
    func getOptInSection() -> Single<OptInSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getOptInSection))
            .handleError()
    }
    
    func sendOptInPermission(permission: OptInPermission, granted: Bool) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendOptInPermission(permissionId: permission.id,
                                                                                      granted: granted,
                                                                                      context: nil)))
            .handleError()
    }
    
    // MARK: - User Consent
    
    func getUserConsentSection() -> Single<ConsentUserDataSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUserConsentSection))
            .handleError()
    }
    
    func submitEmail(email: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .createUserConsent(email: email,
                                                                                    firstName: nil,
                                                                                    lastName: nil,
                                                                                    signatureImage: nil)))
            .handleError()
    }
    
    func verifyEmail(validationCode: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .verifyEmail(validationCode: validationCode)))
            .handleError()
            .catchError({ error -> Single<()> in
                enum ErrorCode: Int, CaseIterable { case wrongValidationCode = 422 }
                if let errorCodeNumber = error.getFirstServerError(forExpectedStatusCodes: ErrorCode.allCases.map { $0.rawValue }),
                    let errorCode = ErrorCode(rawValue: errorCodeNumber) {
                    switch errorCode {
                    case .wrongValidationCode: return Single.error(RepositoryError.wrongEmailValidationCode)
                    }
                } else {
                    return Single.error(error)
                }
            })
    }
    
    func resendConfirmationEmail() -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .resendConfirmationEmail))
            .handleError()
    }
    
    func sendUserData(firstName: String, lastName: String, signatureImage: UIImage) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .createUserConsent(email: nil,
                                                                                    firstName: firstName,
                                                                                    lastName: lastName,
                                                                                    signatureImage: signatureImage)))
            .handleError()
    }
    
    // MARK: - Wearable
    
    func getWearablesSection() -> Single<WearablesSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getWearablesSection))
            .handleError()
    }
    
    // MARK: - Tasks
    
    func getFeeds() -> Single<[Feed]> {
        return self.api.send(request: ApiRequest(serviceRequest: .getTasks))
            .map { (items: ExcludeInvalid<Feed>) in items.wrappedValue }
            .handleError()
    }
    
    func sendQuickActivityResult(quickActivityTaskId: String, quickActivityOption: QuickActivityOption) -> Single<()> {
        let resultData = quickActivityOption.networkResultData.data
        return self.api.send(request: ApiRequest(serviceRequest: .sendTaskResultData(taskId: quickActivityTaskId,
                                                                                     resultData: resultData)))
            .handleError()
    }
    
    func sendTaskResult(taskId: String, taskResult: TaskNetworkResult) -> Single<()> {
        var sendRequest = self.api.send(request: ApiRequest(serviceRequest: .sendTaskResultData(taskId: taskId,
                                                                                                resultData: taskResult.data)))
            .handleError()
        if let taskResultFile = taskResult.attachedFile {
            sendRequest = sendRequest.flatMap {
                self.api.send(request: ApiRequest(serviceRequest: .sendTaskResultFile(taskId: taskId, resultFileString: taskResultFile)))
                .handleError()
            }
        }
        return sendRequest
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
