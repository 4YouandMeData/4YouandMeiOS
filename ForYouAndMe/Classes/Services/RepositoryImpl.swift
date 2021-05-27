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
    
    // InitializableService
    var isInitialized: Bool = false
    
    private let api: ApiGateway
    private var storage: RepositoryStorage
    private let notificationService: NotificationService
    private let analyticsService: AnalyticsService
    private let showDefaultUserInfo: Bool
    
    private let disposeBag = DisposeBag()
    
    init(api: ApiGateway,
         storage: RepositoryStorage,
         notificationService: NotificationService,
         analyticsService: AnalyticsService,
         showDefaultUserInfo: Bool) {
        self.api = api
        self.storage = storage
        self.notificationService = notificationService
        self.analyticsService = analyticsService
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
            .do(onSuccess: { (globalConfig: GlobalConfig) in
                ColorPalette.initialize(withColorMap: globalConfig.colorMap)
                StringsProvider.initialize(withFullStringMap: globalConfig.fullStringMap, requiredStringMap: globalConfig.requiredStringMap)
                CountryCodeProvider.initialize(withcountryCodes: globalConfig.countryCodes)
                IntegrationProvider.initialize(withIntegrationDatas: globalConfig.integrationDatas)
                OnboardingSectionProvider.initialize(withOnboardingSectionGroups: globalConfig.onboardingSectionGroups)
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
    
    var isPinCodeLogin: Bool? {
        return self.storage.globalConfig?.pinCodeLogin
    }
    
    func logOut() {
        self.storage.user = nil
        self.api.logOut()
    }
    
    func sendFirebaseToken(token: String) -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendPushToken(token: token)))
            .handleError()
            .do(onError: { error in print("Repository - error updateFirebaseToken: \(error.localizedDescription)") })
    }
    
    enum SubmitPhoneNumberErrorCode: Int, CaseIterable { case missingPhoneNumber = 404 }
    
    func submitPhoneNumber(phoneNumber: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .submitPhoneNumber(phoneNumber: phoneNumber)))
            .handleError()
            .catchError({ error -> Single<()> in
                
                if let errorCodeNumber = error
                    .getFirstServerError(forExpectedStatusCodes: SubmitPhoneNumberErrorCode.allCases.map { $0.rawValue }),
                    let errorCode = SubmitPhoneNumberErrorCode(rawValue: errorCodeNumber) {
                    switch errorCode {
                    case .missingPhoneNumber: return Single.error(RepositoryError.missingPhoneNumber)
                    }
                } else {
                    return Single.error(error)
                }
            })
    }
    
    enum VerifyPhoneNumberExpectedErrorCode: Int, CaseIterable { case wrongValidationCode = 401 }
    
    func verifyPhoneNumber(phoneNumber: String, validationCode: String) -> Single<User> {
        
        return self.api.send(request: ApiRequest(serviceRequest: .verifyPhoneNumber(phoneNumber: phoneNumber,
                                                                                    validationCode: validationCode)))
            .logServerError(excludingExpectedErrorCodes: VerifyPhoneNumberExpectedErrorCode.allCases.map { $0.rawValue },
                            analyticsService: self.analyticsService)
            .handleError(debugMode: true)
            .catchError({ error -> Single<(User)> in
                if let errorCodeNumber = error
                    .getFirstServerError(forExpectedStatusCodes: VerifyPhoneNumberExpectedErrorCode.allCases.map { $0.rawValue }),
                    let errorCode = VerifyPhoneNumberExpectedErrorCode(rawValue: errorCodeNumber) {
                    switch errorCode {
                    case .wrongValidationCode: return Single.error(RepositoryError.wrongPhoneValidationCode)
                    }
                } else {
                    return Single.error(error)
                }
            })
            .flatMap { user in self.updateUserTimeZoneIfNeeded(user: user) }
            .flatMap { user in self.updateNotificationRegistrationToken(user: user) }
            .map { self.handleUserInfo($0) }
            .do(onSuccess: { self.saveUser($0) })
    }
    
    enum EmailLoginErrorCode: Int, CaseIterable { case wrongValidationCode = 401 }
    
    func emailLogin(email: String) -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .emailLogin(email: email)))
            .handleError()
            .catchError({ (error)-> Single<(User)> in
                if let errorCodeNumber = error
                    .getFirstServerError(forExpectedStatusCodes: EmailLoginErrorCode.allCases.map { $0.rawValue }),
                    let errorCode = EmailLoginErrorCode(rawValue: errorCodeNumber) {
                    switch errorCode {
                    case .wrongValidationCode: return Single.error(RepositoryError.wrongPhoneValidationCode)
                    }
                } else {
                    return Single.error(error)
                }
            })
            .flatMap { user in self.updateUserTimeZoneIfNeeded(user: user) }
            .flatMap { user in self.updateNotificationRegistrationToken(user: user) }
            .map { self.handleUserInfo($0) }
            .do(onSuccess: { self.saveUser($0) })
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
    
    enum VerifyEmailErrorCode: Int, CaseIterable { case wrongValidationCode = 422 }
    
    func verifyEmail(validationCode: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .verifyEmail(validationCode: validationCode)))
            .handleError()
            .catchError({ error -> Single<()> in
                if let errorCodeNumber = error
                    .getFirstServerError(forExpectedStatusCodes: VerifyEmailErrorCode.allCases.map { $0.rawValue }),
                    let errorCode = VerifyEmailErrorCode(rawValue: errorCodeNumber) {
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
    
    func notifyOnboardingCompleted() -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .notifyOnboardingCompleted))
            .handleError()
    }
    
    // MARK: - Integration
    
    func getIntegrationSection() -> Single<IntegrationSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getIntegrationSection))
            .handleError()
    }
    
    // MARK: - Tasks
    
    func getFeeds(fetchMode: FetchMode) -> Single<[Feed]> {
        return self.api.send(request: ApiRequest(serviceRequest: .getFeeds(paginationInfo: fetchMode.paginationInfo)))
            .map { (items: ExcludeInvalid<Feed>) in items.wrappedValue }
            .handleError()
    }
    
    func getTasks(fetchMode: FetchMode) -> Single<[Feed]> {
        return self.api.send(request: ApiRequest(serviceRequest: .getTasks(paginationInfo: fetchMode.paginationInfo)))
            .map { (items: ExcludeInvalid<Feed>) in items.wrappedValue }
            .handleError()
    }
    
    func getTask(taskId: String) -> Single<Feed> {
        return self.api.send(request: ApiRequest(serviceRequest: .getTask(taskId: taskId)))
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
    
    func delayTask(taskId: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .delayTask(taskId: taskId)))
            .handleError()
    }
    
    // MARK: - User
    
    var currentUser: User? {
        self.storage.user
    }
    
    func refreshUser() -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUser))
            .handleError()
            .flatMap { user in self.updateUserTimeZoneIfNeeded(user: user) }
            .flatMap { user in self.updateNotificationRegistrationToken(user: user) }
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
    
    func getUserSettings() -> Single<(UserSettings)> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUserSettings))
            .handleError()
    }
    
    func sendUserSettings(seconds: Int) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendUserSettings(settings: seconds)))
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
    
    // MARK: - Device Data
    
    func sendDeviceData(deviceData: DeviceData) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendDeviceData(deviceData: deviceData)))
            .handleError()
    }
    
    // MARK: - Private Methods
    
    private func updateUserTimeZoneIfNeeded(user: User) -> Single<User> {
        let userTimeZoneIdentifier = user.timeZone?.identifier
        let currentTimeZoneIdentifier = TimeZone.current.identifier
        if currentTimeZoneIdentifier != userTimeZoneIdentifier {
            print("Repository - need to update TimeZone. Previous: '\(userTimeZoneIdentifier ?? "")', new: '\(currentTimeZoneIdentifier)'")
            return self.api.send(request: ApiRequest(serviceRequest: .sendUserTimeZone(timeZoneIdentifier: currentTimeZoneIdentifier)))
                .handleError()
                // Update Time zone is ignored, not blocking operation
                .do(onError: { error in print("Repository - error updateUserTimeZoneIfNeeded: \(error.localizedDescription)") })
                .catchErrorJustReturn(user)
        } else {
            return Single.just(user)
        }
    }
    
    private func handleUserInfo(_ user: User) -> User {
        var user = user
        if self.showDefaultUserInfo && (user.customData ?? []).count == 0 {
            user.customData = Constants.UserInfo.DefaultUserInfoParameters
        }
        return user
    }
    
    private func updateNotificationRegistrationToken(user: User) -> Single<User> {
        return self.notificationService
            .getRegistrationToken()
            .flatMap { token in
                if let token = token {
                    return self.sendFirebaseToken(token: token)
                } else {
                    return Single.just(user)
                }
            }
            .handleError()
            .do(onError: { error in print("RepositoryImpl - Error while updating notification registration token. Error: \(error)") })
            .catchErrorJustReturn(user)
    }
    
    private func saveUser(_ user: User) {
        self.storage.user = user
    }
}

extension RepositoryImpl: NotificationTokenDelegate {
    func registerNotificationToken(token: String) {
        if self.isLoggedIn {
            self.sendFirebaseToken(token: token)
                .subscribe { _ in
                    print("RepositoryImpl - Sent Registration Token to server due to token update")
                } onError: { error in
                    print("RepositoryImpl - Error while sending Registration Token to server due to token update. Error: \(error)")
                }.disposed(by: self.disposeBag)
        }
    }
}

// MARK: - Extension(PrimitiveSequence)

fileprivate extension PrimitiveSequence where Trait == SingleTrait {
    func handleError(debugMode: Bool = false) -> Single<Element> {
        return self.handleServerError(debugMode: debugMode)
    }
    
    func handleServerError(debugMode: Bool = false) -> Single<Element> {
        return self.catchError({ (error) -> Single<Element> in
            if let error = error as? ApiError {
                if debugMode {
                    return Single.error(error.repositoryErrorDebugMode)
                } else {
                    return Single.error(error.repositoryError)
                }
            }
            return Single.error(error)
        })
    }
    
    func logServerError(excludingExpectedErrorCodes expectedErrorCodes: [Int] = [],
                        analyticsService: AnalyticsService) -> Single<Element> {
        return self.do(onError: { error in
            if let error = error as? ApiError,
               nil == error.repositoryError.getFirstServerError(forExpectedStatusCodes: expectedErrorCodes) {
                analyticsService.track(event: .serverError(apiError: error))
            }
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
    
    // Assumes RepositoryError
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

fileprivate extension ApiError {
    var repositoryError: RepositoryError {
        switch self {
        case .cannotParseData: return RepositoryError.remoteServerError
        case .network: return RepositoryError.remoteServerError
        case .connectivity: return RepositoryError.connectivityError
        case .unexpectedError: return RepositoryError.remoteServerError
        case let .expectedError(_, _, _, _, parsedError): return RepositoryError.serverErrorSpecific(error: parsedError)
        case .userUnauthorized: return RepositoryError.userNotLoggedIn
        }
    }
    var repositoryErrorDebugMode: RepositoryError {
        guard let nsError = self.nsError else {
            return self.repositoryError
        }
        switch self {
        case .cannotParseData: return RepositoryError.debugError(error: nsError)
        case .network: return RepositoryError.debugError(error: nsError)
        case .connectivity: return RepositoryError.debugError(error: nsError)
        case .unexpectedError: return RepositoryError.debugError(error: nsError)
        case let .expectedError(_, _, _, _, parsedError): return RepositoryError.serverErrorSpecific(error: parsedError)
        case .userUnauthorized: return RepositoryError.debugError(error: nsError)
        }
    }
}

// MARK: - Extension (FetchMode)

fileprivate extension FetchMode {
    var paginationInfo: PaginationInfo? {
        switch self {
        case .refresh(let pageSize):
            if let pageSize = pageSize {
                return PaginationInfo(pageSize: pageSize, pageIndex: 0)
            } else {
                return nil
            }
        case .append(let paginationInfo): return paginationInfo
        }
    }
}
