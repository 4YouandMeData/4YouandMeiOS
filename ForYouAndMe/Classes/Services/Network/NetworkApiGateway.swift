//
//  NetworkApiGateway.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Moya
import RxSwift
import Reachability

protocol NetworkStorage: AnyObject {
    var accessToken: String? { get set }
}

struct UnhandledError: Mappable {
    init(map: Mapper) throws { throw MapperError.customError(field: nil, message: "Trying to map unhandled error") }
}

class NetworkApiGateway: ApiGateway {
    
    var defaultProvider: MoyaProvider<DefaultService>!
    
    lazy var loggerPlugin: PluginType = {
        let formatter = NetworkLoggerPlugin.Configuration.Formatter(requestData: Data.JSONRequestDataFormatter,
                                                                    responseData: Data.JSONRequestDataFormatter)
        let logOptions: NetworkLoggerPlugin.Configuration.LogOptions = Constants.Test.NetworkLogVerbose
            ? .verbose
            : .default
        let config = NetworkLoggerPlugin.Configuration(formatter: formatter, logOptions: logOptions)
        return NetworkLoggerPlugin(configuration: config)
    }()
    
    lazy var accessTokenPlugin: PluginType = {
        let tokenClosure: (TargetType) -> String = { _ in
            return self.storage.accessToken ?? ""
        }
        let accessTokenPlugin = AccessTokenPlugin(tokenClosure: tokenClosure)
        
        return accessTokenPlugin
    }()
    
    fileprivate let storage: NetworkStorage
    fileprivate let reachability: ReachabilityService
    
    fileprivate let studyId: String
    
    // MARK: - Service Protocol Implementation
    
    public init(studyId: String, reachability: ReachabilityService, storage: NetworkStorage) {
        self.studyId = studyId
        self.reachability = reachability
        self.storage = storage
        self.setupDefaultProvider()
    }
    
    func setupDefaultProvider() {
        self.defaultProvider = MoyaProvider(endpointClosure: self.endpointMapping, plugins: [self.loggerPlugin, self.accessTokenPlugin])
    }
    
    func endpointMapping(forTarget target: DefaultService) -> Endpoint {
        let targetPath = target.getPath(forStudyId: self.studyId)
        let url: URL = {
            if targetPath.isEmpty {
                return target.baseURL
            } else {
                return target.baseURL.appendingPathComponent(targetPath)
            }
        }()
        return Endpoint(url: url.absoluteString,
                        sampleResponseClosure: {.networkResponse(200, target.sampleData)},
                        method: target.method,
                        task: target.task,
                        httpHeaderFields: target.headers)
    }
    
    // MARK: - ApiGateway Protocol Implementation
    
    var accessToken: String? { self.storage.accessToken }
    
    func isLoggedIn() -> Bool {
        return self.storage.accessToken != nil
    }
    
    func logOut() {
        self.storage.accessToken = nil
    }
    
    func send<E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<()> {
        self.sendShared(request: request, errorType: errorType)
            .map { _ in return () }
    }
    
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T> {
        self.sendShared(request: request, errorType: errorType)
            .flatMap { Single.just($0).map(to: T.self).handleMapError(api: self, request: request, response: $0) }
    }
    
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?> {
        self.sendShared(request: request, errorType: errorType)
            .mapOptional(to: T.self)
    }
    
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        self.sendShared(request: request, errorType: errorType)
            .flatMap { response in
                Single.just(response).map(to: [T].self).catch({ (error) in
                    if let error = error as? ApiError {
                        // Network or Server Error
                        return Single.error(error)
                    } else {
                        debugPrint("Response map error: \(error)")
                        return Single.error(ApiError.cannotParseData(pathUrl: request.serviceRequest.getPath(forStudyId: self.studyId),
                                                                     request: request,
                                                                     statusCode: response.statusCode,
                                                                     responseBody: response.body))
                    }
                })
            }
    }
    
    func sendExcludeInvalid<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        self.sendShared(request: request, errorType: errorType)
            .do(onSuccess: { items in
                #if DEBUG
                do { try _ = items.map(to: [T].self) } catch {
                    debugPrint("Response map error: \(error)")
                }
                #endif
            })
            .compactMap(to: [T].self)
    }
    
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T> {
        self.sendShared(request: request, errorType: errorType)
            .flatMap { response in
                Single.just(response).mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
                    .handleMapError(api: self, request: request, response: response)
            }
    }
    
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?> {
        self.sendShared(request: request, errorType: errorType)
            .flatMap { response in
                Single.just(response).mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
                    .handleMapError(api: self, request: request, response: response)
            }
            .catch { error in
                if case ApiError.cannotParseData = error {
                    return Single.just(nil)
                } else {
                    return Single.error(error)
                }
            }
    }
    
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        self.sendShared(request: request, errorType: errorType)
            .flatMap { response in
                Single.just(response).mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
                    .handleMapError(api: self, request: request, response: response)
            }
    }
    
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<ExcludeInvalid<T>> {
        self.sendShared(request: request, errorType: errorType)
            .flatMap { response in
                Single.just(response).mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
                    .handleMapError(api: self, request: request, response: response)
            }
    }
    
    func send<T: PlainDecodable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T> {
        self.sendShared(request: request, errorType: errorType)
            .flatMap { response in
                Single.just(response)
                    .map { response in
                        let decoder = JSONDecoder()
                        return try decoder.decode(T.self, from: response.data)
                    }
                    .handleMapError(api: self, request: request, response: response)
            }
    }
    
    // MARK: - Private Methods
    
    private func sendShared<E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<Response> {
        return self.defaultProvider.rx.request(request.serviceRequest)
            .filterSuccess(api: self, request: request, errorType: errorType)
    }
}

// MARK: - Extension (Single<T>)

fileprivate extension PrimitiveSequence where Trait == SingleTrait {
    
    func handleMapError(api: NetworkApiGateway,
                        request: ApiRequest,
                        response: Response) -> Single<Element> {
        return self.catch({ (error) -> Single<Element> in
            if let error = error as? ApiError {
                // Network or Server Error
                return Single.error(error)
            } else {
                debugPrint("Response map error: \(error)")
                return Single.error(ApiError.cannotParseData(pathUrl: request.serviceRequest.getPath(forStudyId: api.studyId),
                                                             request: request,
                                                             statusCode: response.statusCode,
                                                             responseBody: response.body))
            }
        })
    }
}

// MARK: - Extension (Single<Response>)

fileprivate extension PrimitiveSequence where Trait == SingleTrait, Element == Response {
    
    func filterSuccess<ErrorType: Mappable>(api: NetworkApiGateway,
                                            request: ApiRequest,
                                            errorType: ErrorType.Type) -> Single<Element> {
        return self
            .do(onError: {
                print("Network Error: \($0.localizedDescription)")
            })
            .catch({ error -> Single<Response> in
                // Handle network availability
                if api.reachability.isCurrentlyReachable {
                    return Single.error(ApiError.network(pathUrl: request.serviceRequest.getPath(forStudyId: api.studyId),
                                                         request: request,
                                                         underlyingError: error))
                } else {
                    return Single.error(ApiError.connectivity)
                }
            })
            .flatMap { response -> Single<Element> in
                if 200 ... 299 ~= response.statusCode {
                    // Uncomment this to print the whole response data
//                    print("Network Body: \(String(data: response.data, encoding: .utf8) ?? "")")
                    self.handleAccessToken(response: response, storage: api.storage)
                    return Single.just(response)
                } else {
                    if 400 ... 499 ~= response.statusCode {
                        // Uncomment this to print the whole response data
                        print("Network Body: \(String(data: response.data, encoding: .utf8) ?? "")")
                        if let serverError = ServerErrorCode(rawValue: response.statusCode) {
                            switch serverError {
                            case .unauthorized:
                                if request.isAuthTokenRequired {
                                    let pathUrl = request.serviceRequest.getPath(forStudyId: api.studyId)
                                    return Single.error(ApiError.userUnauthorized(pathUrl: pathUrl,
                                                                                  request: request,
                                                                                  statusCode: response.statusCode,
                                                                                  responseBody: response.body))
                                }
                            }
                        }
                        if let error = try? response.map(to: errorType) {
                            return Single.error(ApiError.expectedError(pathUrl: request.serviceRequest.getPath(forStudyId: api.studyId),
                                                                       request: request,
                                                                       statusCode: response.statusCode,
                                                                       responseBody: response.body,
                                                                       parsedError: error))
                        }
                    }
                    // Uncomment this to print the whole response data
                    print("Network Body: \(String(data: response.data, encoding: .utf8) ?? "")")
                    return Single.error(ApiError.unexpectedError(pathUrl: request.serviceRequest.getPath(forStudyId: api.studyId),
                                                                 request: request,
                                                                 statusCode: response.statusCode,
                                                                 responseBody: response.body))
                }
            }
    }
    
    private func handleAccessToken(response: Response, storage: NetworkStorage) {
        if var accessToken = response.response?.allHeaderFields["Authorization"] as? String {
            accessToken = accessToken.replacingOccurrences(of: "Bearer ", with: "")
            storage.accessToken = accessToken
        }
    }
}

fileprivate extension ApiRequest {
    var isAuthTokenRequired: Bool {
        nil != self.serviceRequest.authorizationType
    }
}

// MARK: - TargetType Protocol Implementation
extension DefaultService: TargetType, AccessTokenAuthorizable {
    
    var baseURL: URL { return URL(string: Constants.Network.ApiBaseUrlStr)! }
    
    func getPath(forStudyId studyId: String) -> String {
        switch self {
        // Misc
        case .getGlobalConfig:
            return "/v1/studies/\(studyId)/configuration"
        case .getStudy:
            return "/v1/studies/\(studyId)"
        // Login
        case .submitPhoneNumber:
            return "/v1/studies/\(studyId)/auth/verify_phone_number"
        case .verifyPhoneNumber:
            return "/v1/studies/\(studyId)/auth/login"
        case .emailLogin:
            return "/v1/studies/\(studyId)/auth/email_login"
        // Onboarding Section
        case .submitProfilingOption(let questionId, _):
            return "/v1/profiling_questions/\(questionId)/user_profiling_questions"
        // Screening Section
        case .getScreeningSection:
            return "/v1/studies/\(studyId)/screening"
        // Informed Consent Section
        case .getInformedConsentSection:
            return "/v1/studies/\(studyId)/informed_consent"
        // Onboarding Questions
        case .getOnboardingQuestionsSection:
            return "/v1/studies/\(studyId)/onboarding_questionnaire"
        // Consent Section
        case .getConsentSection:
            return "/v1/studies/\(studyId)/consent"
        // Opt In Section
        case .getOptInSection:
            return "/v1/studies/\(studyId)/opt_in"
        case .sendOptInPermission(let permissionId, _, _):
            return "/v1/permissions/\(permissionId)/user_permission"
        // User Consent Section
        case .getUserConsentSection:
            return "/v1/studies/\(studyId)/signature"
        case .createOtherUserConsent(let consentId, _):
            return "/v1/user_consents/\(consentId)/other_user_consents"
        case .createUserConsent, .updateUserConsent:
            return "/v1/studies/\(studyId)/user_consent"
        case .notifyOnboardingCompleted:
            return "/v1/studies/\(studyId)/user_consent"
        case .verifyEmail:
            return "/v1/studies/\(studyId)/user_consent/confirm_email"
        case .resendConfirmationEmail:
            return "/v1/studies/\(studyId)/user_consent/resend_confirmation_email"
        // Integration Section
        case .getIntegrationSection:
            return "/v1/studies/\(studyId)/integration"
        case .getStudyInfoSection:
            return "/v1/studies/\(studyId)/study_info"
        // Answers
        case .sendAnswer(let answer, _):
            return "v1/questions/\(answer.question.id)/answer"
        // Feeds
        case .getFeeds:
            return "v1/feeds"
        // Task
        case .getTasks:
            return "v1/tasks"
        case .getTask(let taskId):
            return "v1/tasks/\(taskId)"
        case .sendTaskResultData(let taskId, _):
            return "v1/tasks/\(taskId)"
        case .sendTaskResultFile(let taskId, _):
            return "v1/tasks/\(taskId)/attach"
        case .delayTask(let taskId):
            return "v1/tasks/\(taskId)/reschedule"
        // User
        case .getUser:
            return "v1/users/me"
        case .sendUserInfoParameters:
            return "v1/users/me"
        case .sendUserTimeZone:
            return "v1/users/me"
        case .sendPushToken:
            return "v1/users/me/add_firebase_token"
        case .sendWalthroughDone:
            return "v1/users/me"
        // User Data
        case .getUserData:
            return "v1/studies/\(studyId)/your_data"
        case .getUserSettings:
            return "/v1/user_setting"
        case .sendUserSettings:
            return "/v1/user_setting"
        // Survey
        case .getSurvey(let surveyId):
            return "v1/surveys/\(surveyId)"
        case .sendSurveyTaskResultData(let surveyTaskId, _):
            return "v1/tasks/\(surveyTaskId)"
        // Device Data
        case .sendDeviceData:
            return "v1/phone_events"
        // Health
        case .sendHealthData, .sendSpyroResults:
            return "v1/integration_datas"
        // Phase
        case .createUserPhase(let phaseId):
            return "v1/study_phases/\(phaseId)/user_study_phases"
        case .updateUserPhase(let userPhaseId):
            return "v1/user_study_phases/\(userPhaseId)"
        case .getDiaryNotes:
            return "v1/diary_notes"
        case .getDiaryNoteText(let diaryNoteId):
            return "v1/diary_notes/\(diaryNoteId)"
        case .getDiaryNoteAudio(let diaryNoteId):
            return "v1/diary_notes/\(diaryNoteId)"
        case .sendDiaryNoteText:
            return "v1/diary_notes"
        case .sendDiaryNoteEaten:
            return "v1/diary_notes"
        case .deleteDiaryNote(let diaryNoteId):
            return "v1/diary_notes/\(diaryNoteId)"
        case .sendDiaryNoteAudio(_, _, _):
            return "v1/diary_notes"
        case .sendDiaryNoteVideo(_, _):
            return "v1/diary_notes"
        case .updateDiaryNoteText(let diaryNoteId):
            return "v1/diary_notes/\(diaryNoteId.id)"
        case .getInfoMessages:
            return "v1/studies/\(studyId)/app_info_messages"
        }
    }
    
    // Need this to conform to TargetType protocol. getPath(forStudyId) is used instead
    var path: String { "" }
    
    var method: Moya.Method {
        switch self {
        case .getGlobalConfig,
                .getStudy,
                .getScreeningSection,
                .getInformedConsentSection,
                .getConsentSection,
                .getOptInSection,
                .getUserConsentSection,
                .getIntegrationSection,
                .getStudyInfoSection,
                .getOnboardingQuestionsSection,
                .getFeeds,
                .getTasks,
                .getTask,
                .getSurvey,
                .getUser,
                .getUserData,
                .getUserSettings,
                .getDiaryNotes,
                .getDiaryNoteText,
                .getInfoMessages,
                .getDiaryNoteAudio:
            return .get
        case .submitPhoneNumber,
                .verifyPhoneNumber,
                .submitProfilingOption,
                .emailLogin,
                .createUserConsent,
                .createOtherUserConsent,
                .notifyOnboardingCompleted,
                .sendOptInPermission,
                .sendAnswer,
                .sendDeviceData,
                .sendHealthData,
                .sendSpyroResults,
                .createUserPhase,
                .sendDiaryNoteText,
                .sendDiaryNoteAudio,
                .sendDiaryNoteVideo,
                .sendDiaryNoteEaten:
            return .post
        case .verifyEmail,
                .resendConfirmationEmail,
                .updateUserConsent,
                .sendTaskResultData,
                .sendTaskResultFile,
                .sendUserInfoParameters,
                .sendUserTimeZone,
                .sendUserSettings,
                .sendPushToken,
                .sendWalthroughDone,
                .sendSurveyTaskResultData,
                .delayTask,
                .updateUserPhase,
                .updateDiaryNoteText:
            return .patch
        case .deleteDiaryNote:
            return .delete
        }
    }
    
    var sampleData: Data {
        switch self {
        // Misc
        case .getGlobalConfig: return Bundle.getTestData(from: "TestGetGlobalConfig")
        case .getStudy: return Bundle.getTestData(from: "TestGetStudy")
        // Login
        case .submitPhoneNumber: return "{}".utf8Encoded
        case .verifyPhoneNumber, .emailLogin:
            return Constants.Test.OnboardingCompleted
                ? Bundle.getTestData(from: "TestGetUser")
                : Bundle.getTestData(from: "TestGetUserNoOnboarding")
        case .submitProfilingOption: return "{}".utf8Encoded
        // Screening Section
        case .getScreeningSection: return Bundle.getTestData(from: "TestGetScreeningSection")
        // Informed Consent Section
        case .getInformedConsentSection:
            if Constants.Test.InformedConsentWithoutQuestions {
                return Bundle.getTestData(from: "TestGetInformedConsentSectionNoQuestions")
            } else {
                return Bundle.getTestData(from: "TestGetInformedConsentSection")
            }
        // Consent Section
        case .getConsentSection: return Bundle.getTestData(from: "TestGetConsentSection")
        // Opt In Section
        case .getOptInSection: return Bundle.getTestData(from: "TestGetOptInSection")
        case .sendOptInPermission: return "{}".utf8Encoded
        // User Consent Section
        case .getUserConsentSection: return Bundle.getTestData(from: "TestGetUserConsentSection")
        case .createUserConsent: return "{}".utf8Encoded
        case .createOtherUserConsent: return "{}".utf8Encoded
        case .updateUserConsent: return "{}".utf8Encoded
        case .notifyOnboardingCompleted: return "{}".utf8Encoded
        case .verifyEmail: return "{}".utf8Encoded
        case .resendConfirmationEmail: return "{}".utf8Encoded
        // Integration Section
        case .getIntegrationSection: return Bundle.getTestData(from: "TestGetIntegrationSection")
        // StudyInfo
        case .getStudyInfoSection: return Bundle.getTestData(from: "TestGetStudyInfo")
        case .getOnboardingQuestionsSection: return "{}".utf8Encoded
        // Answers
        case .sendAnswer: return "{}".utf8Encoded
        // Task
        case .getFeeds, .getTasks: return Bundle.getTestData(from: "TestGetTasks")
        case .getTask: return Bundle.getTestData(from: "TaskGetTaskVideoDiary")
        case .sendTaskResultData: return "{}".utf8Encoded
        case .sendTaskResultFile: return "{}".utf8Encoded
        case .delayTask: return "{}".utf8Encoded
        case .getInfoMessages: return "{}".utf8Encoded
        // User
        case .getUser:
            return Constants.Test.OnboardingCompleted
                ? Bundle.getTestData(from: "TestGetUser")
                : Bundle.getTestData(from: "TestGetUserNoOnboarding")
        case .sendUserInfoParameters:
            return Constants.Test.OnboardingCompleted
                ? Bundle.getTestData(from: "TestGetUser")
                : Bundle.getTestData(from: "TestGetUserNoOnboarding")
        case .sendUserTimeZone:
            return Constants.Test.OnboardingCompleted
                ? Bundle.getTestData(from: "TestGetUser")
                : Bundle.getTestData(from: "TestGetUserNoOnboarding")
        case .sendPushToken:
            return Constants.Test.OnboardingCompleted
                ? Bundle.getTestData(from: "TestGetUser")
                : Bundle.getTestData(from: "TestGetUserNoOnboarding")
        case .sendWalthroughDone: return "{}".utf8Encoded
        // User Data
        case .getUserData: return Bundle.getTestData(from: "TestGetUserData")
        case .sendUserSettings: return "{}".utf8Encoded
        case .getUserSettings: return "{}".utf8Encoded
        // Survey
        case .getSurvey: return Bundle.getTestData(from: "TestGetSurvey")
        case .sendSurveyTaskResultData: return "{}".utf8Encoded
        // Device Data
        case .sendDeviceData: return "{}".utf8Encoded
        // Health
        case .sendHealthData: return "{}".utf8Encoded
        case .sendSpyroResults: return "{}".utf8Encoded
        // User Phase
        case .createUserPhase: return "{}".utf8Encoded
        case .updateUserPhase: return "{}".utf8Encoded
        case .getDiaryNotes: return "{}".utf8Encoded
        case .sendDiaryNoteText: return "{}".utf8Encoded
        case .sendDiaryNoteAudio: return "{}".utf8Encoded
        case .sendDiaryNoteVideo: return "{}".utf8Encoded
        case .sendDiaryNoteEaten: return "{}".utf8Encoded
        case .getDiaryNoteText: return "{}".utf8Encoded
        case .getDiaryNoteAudio: return "{}".utf8Encoded
        case .deleteDiaryNote: return "{}".utf8Encoded
        case .updateDiaryNoteText: return "{}".utf8Encoded
        }
    }
    
    var task: Task {
        switch self {
        case .getGlobalConfig,
                .getStudy,
                .getScreeningSection,
                .getInformedConsentSection,
                .getConsentSection,
                .getOptInSection,
                .getStudyInfoSection,
                .getUserConsentSection,
                .resendConfirmationEmail,
                .getIntegrationSection,
                .getOnboardingQuestionsSection,
                .getTask,
                .getSurvey,
                .getUser,
                .getUserSettings,
                .getUserData,
                .delayTask,
                .getDiaryNoteText,
                .getDiaryNoteAudio,
                .getInfoMessages,
                .deleteDiaryNote:
            return .requestPlain
        case .submitPhoneNumber(let phoneNumber):
            var params: [String: Any] = [:]
            params["phone_number"] = phoneNumber
            return .requestParameters(parameters: ["user": params], encoding: JSONEncoding.default)
        case .verifyPhoneNumber(let phoneNumber, let secureCode):
            var params: [String: Any] = [:]
            params["phone_number"] = phoneNumber
            params["verification_code"] = secureCode
            return .requestParameters(parameters: ["user": params],
                                      encoding: JSONEncoding.default)
        case .emailLogin(let email):
            var params: [String: Any] = [:]
            params["email"] = email
            params["password"] = "fake_password"
            return .requestParameters(parameters: ["user": params],
                                      encoding: JSONEncoding.default)
        case .submitProfilingOption(_, let optionId):
            var params: [String: Any] = [:]
            params["profiling_option_id"] = optionId
            return .requestParameters(parameters: ["user_profiling_question": params],
                                      encoding: JSONEncoding.default)
        case let .createUserConsent(consentData):
            return Task.createForUserContent(consentData: consentData)
        case let .createOtherUserConsent(_, userConsentData):
            return Task.createForUserContentForMinor(consentData: userConsentData)
        case let .updateUserConsent(consentData):
            return Task.createForUserContent(consentData: consentData)
        case .notifyOnboardingCompleted:
            let data = UserConsentData(email: nil,
                                       firstName: nil,
                                       lastName: nil,
                                       guardianFirstName: nil,
                                       guardianLastName: nil,
                                       relation: nil,
                                       signatureImage: nil,
                                       additionalImage: nil,
                                       isCreate: true)
            return Task.createForUserContent(consentData: data)
        case .verifyEmail(let email):
            var params: [String: Any] = [:]
            params["email_confirmation_token"] = email
            return .requestParameters(parameters: ["user_consent": params], encoding: JSONEncoding.default)
        case .sendOptInPermission(_, let granted, let context):
            var params: [String: Any] = [:]
            params["agree"] = granted
            params.addContext(context)
            return .requestParameters(parameters: ["user_permission": params], encoding: JSONEncoding.default)
        case .sendAnswer(let answer, let context):
            var params: [String: Any] = [:]
            params["answer_text"] = answer.possibleAnswer.text
            params["possible_answer_id"] = answer.possibleAnswer.id
            params.addContext(context)
            return .requestParameters(parameters: ["answer": params], encoding: JSONEncoding.default)
        case .sendTaskResultData(_, let resultData):
            var params: [String: Any] = [:]
            params["result"] = resultData
            return .requestParameters(parameters: ["task": params], encoding: JSONEncoding.default)
        case .sendTaskResultFile:
            return .uploadMultipart(self.multipartBody)
        case .sendUserInfoParameters(let userParameters):
            let customDataParams: [[String: Any]] = userParameters.reduce([]) { (result, parameter) in
                let newParameter = UserInfoParameter.create(fromParameter: parameter.parameter, withValue: parameter.value)
                var result = result
                if let data = try? JSONEncoder().encode(newParameter),
                   let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                    result.append(dictionary)
                }
                return result
            }
            var params: [String: Any] = [:]
            params["custom_data"] = customDataParams
            return .requestParameters(parameters: ["user": params], encoding: JSONEncoding.default)
        case .sendUserSettings(let seconds):
            var params: [String: Any] = [:]
            params["daily_survey_time_seconds_since_midnight"] = seconds
            return .requestParameters(parameters: ["user_setting": params], encoding: JSONEncoding.default)
        case .sendPushToken(let token):
            var params: [String: Any] = [:]
            params["firebase_token"] = token
            return .requestParameters(parameters: ["user": params], encoding: JSONEncoding.default)
        case .sendWalthroughDone:
            var params: [String: Any] = [:]
            params["study_walkthrough_done"] = true
            return .requestParameters(parameters: ["user": params], encoding: JSONEncoding.default)
        case .sendUserTimeZone(let timeZoneIdentifier):
            return .requestParameters(parameters: ["time_zone": timeZoneIdentifier], encoding: JSONEncoding.default)
        case .sendSurveyTaskResultData(_, let results):
            let answerParams: [[String: Any]] = results.reduce([]) { (result, parameter) in
                var result = result
                var userParameter: [String: Any] = [:]
                userParameter["question_id"] = parameter.question.id
                
                // Pick Many Answers
                if let pickManyResponses = parameter.answer as? [SurveyPickResponse] {
                    let pickManyResponsesEncoded: [[String: Any]] = pickManyResponses.reduce([]) { (result, pickManyResponse) in
                        var result = result
                        if let data = try? JSONEncoder().encode(pickManyResponse),
                           let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                            result.append(dictionary)
                        }
                        return result
                    }
                    userParameter["answer"] = pickManyResponsesEncoded
                } else if let data = try? JSONEncoder().encode(parameter.answer as? SurveyPickResponse), // Pick One Answers
                          let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                    userParameter["answer"] = dictionary
                } else if let clickableResponses = parameter.answer as? [SurveyClickableResponse] {
                    let clickableResponsesEncoded: [[String: Any]] = clickableResponses.reduce([]) { (result, clickableResponse) in
                        var result = result
                        if let data = try? JSONEncoder().encode(clickableResponse),
                           let dictionary = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                            result.append(dictionary)
                        }
                        return result
                    }
                    userParameter["answer"] = clickableResponsesEncoded
                } else {
                    userParameter["answer"] = parameter.answer // Other survey Answers
                }
                result.append(userParameter)
                return result
            }
            let resultData: [String: Any] = ["answers": answerParams]
            let params: [String: Any] = ["result": resultData]
            return .requestParameters(parameters: ["task": params], encoding: JSONEncoding.default)
        case .getFeeds(let paginationInfo):
            return self.getDefaultFeedsNetworkTask(forPaginationInfo: paginationInfo)
        case .getTasks(let paginationInfo):
            return self.getDefaultFeedsNetworkTask(forPaginationInfo: paginationInfo)
        case .sendDeviceData(let deviceData):
            var params: [String: Any] = [:]
            params["battery_level"] = deviceData.batteryLevel
            params["longitude"] = deviceData.longitude.unwrapOrNull
            params["latitude"] = deviceData.latitude.unwrapOrNull
            params["location_permission"] = deviceData.locationPermission
            params["time_zone"] = deviceData.timezone
            params["hashed_ssid"] = deviceData.hashedSSID.unwrapOrNull
            params["timestamp"] = deviceData.timestamp
            let dataParams: [String: Any] = ["data": params]
            return .requestParameters(parameters: ["phone_event": dataParams], encoding: JSONEncoding.default)
        case .sendHealthData(let healthData, let source):
            var dataParams: [String: Any] = ["data": healthData]
            dataParams["source"] = source
            if let subsourceKey = healthData.keys.first, !subsourceKey.isEmpty {
                dataParams["subsource"] = subsourceKey
            } else {
                dataParams["subsource"] = "generic"
            }
            return .requestParameters(parameters: ["integration_data": dataParams], encoding: JSONEncoding.default)
        case .sendSpyroResults(let results):
            var dataParams: [String: Any] = ["data": results]
            dataParams["source"] = "mir_spirometer"
            dataParams["subsource"] = "generic"
            return .requestParameters(parameters: ["integration_data": dataParams], encoding: JSONEncoding.default)
        case .updateUserPhase:
            let dateString = ISO8601Strategy.encode(Date())
            let dataParams: [String: Any] = ["end_at": dateString]
            return .requestParameters(parameters: ["user_study_phase": dataParams], encoding: JSONEncoding.default)
        case .createUserPhase:
            let dateString = ISO8601Strategy.encode(Date())
            var dataParams: [String: Any] = [:]
            dataParams["start_at"] = dateString
            dataParams["custom_data"] = [String: Any]()
            return .requestParameters(parameters: ["user_study_phase": dataParams], encoding: JSONEncoding.default)
        case .getDiaryNotes(let diaryNote, let fromChart):
            var params: [String: Any] = [:]
                var qDict: [String: Any] = [
                    "sorts": "datetime_ref desc"
                ]
                
                // Solo se fromChart è true inserisco i parametri in_chart_interval
                if fromChart {
                    if let dateString = diaryNote?.diaryNoteId.string(withFormat: dateTimeFormat) {
                        qDict["in_chart_interval"] =  [dateString, diaryNote?.interval]
                    }
                }

            params["q"] = qDict
            let encoding = URLEncoding(destination: .queryString, arrayEncoding: .brackets, boolEncoding: .literal)
            return .requestParameters(parameters: params, encoding: encoding)
        case .updateDiaryNoteText(let diaryNote):
            var dataParams: [String: Any] = [:]
            dataParams["title"] = diaryNote.title
            dataParams["body"] = diaryNote.body
            return .requestParameters(parameters: ["diary_note": dataParams], encoding: JSONEncoding.default)
        case .sendDiaryNoteText(let diaryNote, let fromChart):
            if fromChart {
                var dataParams: [String: Any] = [:]
                dataParams["body"] = diaryNote.body
                dataParams["datetime_ref"] = diaryNote.diaryNoteId.string(withFormat: dateTimeFormat)
                dataParams["diary_noteable_type"] = diaryNote.diaryNoteable?.type
                dataParams["diary_noteable_id"] = diaryNote.diaryNoteable?.id
                dataParams["interval"] = diaryNote.interval
                return .requestParameters(parameters: ["diary_note": dataParams], encoding: JSONEncoding.default)
            }
            
            return .requestJSONEncodable(diaryNote)
        case .sendDiaryNoteEaten(let date, let mealType, let quantity, let significantNutrition, let fromChart):
            var data: [String: Any] = [:]
            data["quantity"] = quantity
            data["with_significant_protein_fiber_or_fat"] = significantNutrition
            data["meal_type"] = mealType
            
            var dataParams: [String: Any] = [:]
            dataParams["data"] = data
            dataParams["datetime_ref"] = date.string(withFormat: dateTimeFormat)
            dataParams["diary_type"] = DiaryNoteItemType.eaten.rawValue
            
            return .requestParameters(parameters: ["diary_note": dataParams], encoding: JSONEncoding.default)
            
        case .sendDiaryNoteAudio(let diaryNote, _, _):
            // Add parameters
            var multipartBodyReq = self.multipartBody
            
            let parameters: [String: String] = [
                "diary_note[body]": diaryNote.body ?? "",
                "diary_note[datetime_ref]": diaryNote.diaryNoteId.string(withFormat: dateTimeFormat),
                "diary_note[diary_noteable_type]": diaryNote.diaryNoteable?.type ?? "",
                "diary_note[diary_noteable_id]": diaryNote.diaryNoteable?.id ?? "",
                "diary_note[interval]": diaryNote.interval ?? ""
            ]
            
            for (key, value) in parameters {
                let parameterData = MultipartFormData(provider: .data(value.data(using: .utf8)!),
                                                      name: key)
                multipartBodyReq.append(parameterData)
            }
            
            return .uploadMultipart(multipartBodyReq)
            
        case .sendDiaryNoteVideo(let diaryNote, _):
            var multipartBodyReq = self.multipartBody
            
            let parameters: [String: String] = [
                "diary_note[body]": diaryNote.body ?? "",
                "diary_note[datetime_ref]": diaryNote.diaryNoteId.string(withFormat: dateTimeFormat),
                "diary_note[diary_noteable_type]": diaryNote.diaryNoteable?.type ?? "",
                "diary_note[diary_noteable_id]": diaryNote.diaryNoteable?.id ?? "",
                "diary_note[interval]": diaryNote.interval ?? ""
            ]
            
            for (key, value) in parameters {
                let parameterData = MultipartFormData(provider: .data(value.data(using: .utf8)!),
                                                      name: key)
                multipartBodyReq.append(parameterData)
            }
            
            return .uploadMultipart(multipartBodyReq)
        }
    }
    
    var multipartBody: [MultipartFormData] {
        switch self {
        case .sendTaskResultFile(_, let file):
            let imageDataProvider = MultipartFormData(provider: MultipartFormData.FormDataProvider.data(file.data),
                                                      name: "task[attachment]",
                                                      fileName: "VideoDiary.\(file.fileExtension.name)",
                                                      mimeType: file.fileExtension.mimeType)
            return [imageDataProvider]
        case .sendDiaryNoteAudio(_, let file, _):
            let audioDataProvider = MultipartFormData(provider: MultipartFormData.FormDataProvider.data(file.data),
                                                      name: "diary_note[attachment]",
                                                      fileName: "AudioNote.\(file.fileExtension.name)",
                                                      mimeType: file.fileExtension.mimeType)
            return [audioDataProvider]
        case .sendDiaryNoteVideo(_, let file):
            let videoDataProvider = MultipartFormData(provider: MultipartFormData.FormDataProvider.data(file.data),
                                                      name: "diary_note[attachment]",
                                                      fileName: "VideoNote.\(file.fileExtension.name)",
                                                      mimeType: file.fileExtension.mimeType)
            return [videoDataProvider]
        default:
            return []
        }
    }
    
    var headers: [String: String]? {
        return ["Content-type": "application/json"]
    }
    
    var authorizationType: AuthorizationType? {
        switch self {
        case .getGlobalConfig,
                .getStudy,
                .submitPhoneNumber,
                .emailLogin,
                .verifyPhoneNumber:
            return nil
        case .getScreeningSection,
                .getInformedConsentSection,
                .getConsentSection,
                .getOnboardingQuestionsSection,
                .getOptInSection,
                .sendOptInPermission,
                .submitProfilingOption,
                .getUserConsentSection,
                .createUserConsent,
                .createOtherUserConsent,
                .updateUserConsent,
                .notifyOnboardingCompleted,
                .getStudyInfoSection,
                .verifyEmail,
                .resendConfirmationEmail,
                .getIntegrationSection,
                .sendAnswer,
                .getFeeds,
                .getTasks,
                .getTask,
                .sendTaskResultData,
                .sendTaskResultFile,
                .getUser,
                .sendUserTimeZone,
                .sendUserInfoParameters,
                .getUserSettings,
                .sendUserSettings,
                .getUserData,
                .getSurvey,
                .sendSurveyTaskResultData,
                .sendPushToken,
                .sendWalthroughDone,
                .delayTask,
                .sendDeviceData,
                .sendHealthData,
                .sendSpyroResults,
                .createUserPhase,
                .updateUserPhase,
                .getDiaryNotes,
                .getDiaryNoteText,
                .getDiaryNoteAudio,
                .sendDiaryNoteText,
                .sendDiaryNoteAudio,
                .sendDiaryNoteVideo,
                .sendDiaryNoteEaten,
                .deleteDiaryNote,
                .getInfoMessages,
                .updateDiaryNoteText:
            return .bearer
        }
    }
    
    private func getDefaultFeedsNetworkTask(forPaginationInfo paginationInfo: PaginationInfo?) -> Task {
        var params: [String: Any] = [:]
        //        params["q"] = [
        //            ["active": true],
        //            ["not_completed": true],
        //            ["s": "from desc"]
        //        ]
        if let paginationInfo = paginationInfo {
            params["page"] = paginationInfo.pageIndex + 1 // Server starts to count from 1
            params["per_page"] = paginationInfo.pageSize
        }
        // Needed by the server so it knows that the client supports images as url
        params["url_images_encoding"] = 1
        let encoding = URLEncoding(destination: .queryString, arrayEncoding: .noBrackets, boolEncoding: .literal)
        return .requestParameters(parameters: params, encoding: encoding)
    }
    
    private func getDatapointInformations(forDatapoint dataPoint: String) -> Task {
        var params: [String: Any] = [:]
                params["q"] = [
                    ["order": "datetime_ref_desc"]
                ]
        let encoding = URLEncoding(destination: .queryString, arrayEncoding: .noBrackets, boolEncoding: .literal)
        return .requestParameters(parameters: params, encoding: encoding)
    }
}

fileprivate extension Task {
    static func createForUserContent(consentData: UserConsentData) -> Task {
        var params: [String: Any] = [:]
        if consentData.isCreate {
            params["agree"] = true
        }
        if let email = consentData.email {
            params["new_email"] = email
        }
        if let firstName = consentData.firstName {
            params["first_name"] = firstName
        }
        if let lastName = consentData.lastName {
            params["last_name"] = lastName
        }
        
        if let signatureBase64 = convertImageToBase64(consentData.signatureImage) {
            params["signature_base64"] = signatureBase64
        }
        params["on_boarding_completed_at"] = Date().string(withFormat: "yyyy-MM-dd")

        return .requestParameters(parameters: ["user_consent": params], encoding: JSONEncoding.default)
    }
    
    static func createForUserContentForMinor(consentData: UserConsentData) -> Task {
    
        let task: Task = {
                guard let guardianFirstName = consentData.guardianFirstName,
                      let guardianLastName = consentData.guardianLastName,
                      let guardianSignatureImage = consentData.additionalImage,
                      let guardianRelation = consentData.relation else {
                    return .requestParameters(parameters: [:], encoding: JSONEncoding.default)
                }
                
                let guardianSignatureBase64 = convertImageToBase64(guardianSignatureImage)
                var guardianDict: [String: Any] = [:]
                guardianDict["first_name"] = guardianFirstName
                guardianDict["last_name"] = guardianLastName
                guardianDict["user_consent_type"] = guardianRelation
                guardianDict["signature_base64"] = guardianSignatureBase64 ?? ""
                
                return .requestParameters(parameters: ["other_user_consent": guardianDict],
                                          encoding: JSONEncoding.default)
            }()
            
            return task
    }
    
    private static func convertImageToBase64(_ image: UIImage?) -> String? {
        guard let image = image else { return nil }
        guard let imageData = image.pngData() else {
            assertionFailure("Cannot convert image data to PNG")
            return nil
        }
        let base64String = imageData.base64EncodedString()
        return "data:image/png;base64,\(base64String)"
    }
}

fileprivate extension Dictionary where Key == String, Value == Any {
    mutating func addContext(_ optionalContext: ApiContext?) {
        let context = optionalContext ?? ApiContext()
        self["batch_code"] = context.batchIdentifier
    }
}

fileprivate extension FileDataExtension {
    var name: String {
        switch self {
        case .mp4: return "mp4"
        case .m4a: return "m4a"
        }
    }
    var mimeType: String {
        switch self {
        case .mp4: return "video/mp4"
        case .m4a: return "audio/m4a"
        }
    }
}
