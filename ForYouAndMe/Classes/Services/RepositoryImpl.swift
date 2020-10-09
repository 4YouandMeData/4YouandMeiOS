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
    var user: User? { get set }
}

class RepositoryImpl {
    
    var isInitialized: Bool = false
    
    private var storage: RepositoryStorage
    private let api: ApiGateway
    private let showDefaultUserInfo: Bool
    
    init(api: ApiGateway,
         storage: RepositoryStorage,
         showDefaultUserInfo: Bool) {
        self.api = api
        self.storage = storage
        self.showDefaultUserInfo = showDefaultUserInfo
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
        self.storage.user = nil
        self.api.logOut()
    }
    
    func sendFirebaseToken(token: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .submitPhoneNumber(phoneNumber: token)))
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
    
    func verifyPhoneNumber(phoneNumber: String, validationCode: String) -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .verifyPhoneNumber(phoneNumber: phoneNumber,
                                                                                    validationCode: validationCode)))
            .handleError()
            .do(onSuccess: { (user: User) in
                print("Current user: \(user)")
                self.storage.user = user
            })
            .catchError({ (error)-> Single<(User)> in
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
    
    // MARK: - Study Info Section
    
    func getStudyInfoSection() -> Single<StudyInfoSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getStudyInfoSection))
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
    
    // MARK: - Integration
    
    func getIntegrationSection() -> Single<IntegrationSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getIntegrationSection))
            .handleError()
    }
    
    // MARK: - Tasks
    
    func getFeeds() -> Single<[Feed]> {
        return self.api.send(request: ApiRequest(serviceRequest: .getFeeds))
            .map { (items: ExcludeInvalid<Feed>) in items.wrappedValue }
            .handleError()
    }
    
    func getTasks() -> Single<[Feed]> {
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
                self.api.send(request: ApiRequest(serviceRequest: .sendTaskResultFile(taskId: taskId, resultFile: taskResultFile)))
                .handleError()
            }
        }
        return sendRequest
    }
    
    // MARK: - User
    
    var currentUser: User? {
        self.storage.user
    }
    
    func refreshUser() -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUser))
            .handleError()
            .map { self.handleUserInfo($0) }
            .do(onSuccess: { self.saveUser($0) })
    }
    
    func sendUserInfoParameters(userParameterRequests: [UserInfoParameterRequest]) -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendUserInfoParameters(paramenters: userParameterRequests)))
            .handleError()
            .map { self.handleUserInfo($0) }
            .do(onSuccess: { self.saveUser($0) })
    }
    
    // MARK: - User Data
    
    func getUserData() -> Single<UserData> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUserData))
            .handleError()
    }
    
    func getUserDataAggregation(period: StudyPeriod) -> Single<[UserDataAggregation]> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUserDataAggregation(period: period)))
            .handleError()
    }
    
    // MARK: - Survey
    
    func getSurvey(surveyId: String) -> Single<SurveyGroup> {
        return self.api.send(request: ApiRequest(serviceRequest: .getSurvey(surveyId: surveyId)))
            .handleError()
    }
    
    func sendSurveyTaskResult(surveyTaskId: String, results: [SurveyResult]) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendSurveyTaskResultData(surveyTaskId: surveyTaskId, results: results)))
            .handleError()
    }
    
    // MARK: - Private Methods
    
    func handleUserInfo(_ user: User) -> User {
        var user = user
        if self.showDefaultUserInfo && (user.customData ?? []).count == 0 {
            user.customData = Constants.UserInfo.DefaultUserInfoParameters
        }
        return user
    }
    
    func saveUser(_ user: User) {
        self.storage.user = user
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
        
        var requests = self.fetchGlobalConfig()
        
        if self.isLoggedIn {
            requests = requests.flatMap {
                self.refreshUser()
                    .toVoid()
                    .catchErrorJustReturn(())
            }
        }
        
        return requests
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
