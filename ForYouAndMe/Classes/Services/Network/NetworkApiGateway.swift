//
//  NetworkApiGateway.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import Moya
import Moya_ModelMapper
import RxSwift
import Mapper
import Japx
import Reachability

protocol NetworkStorage: class {
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
        let tokenClosure: (AuthorizationType) -> String = { authorizationType in
            switch authorizationType {
            case .basic: return ""
            case .bearer: return self.storage.accessToken ?? ""
            case .custom: return ""
            }
        }
        let accessTokenPlugin = AccessTokenPlugin(tokenClosure: tokenClosure)
        
        return accessTokenPlugin
    }()
    
    fileprivate let storage: NetworkStorage
    fileprivate let reachability: ReachabilityService
    
    private let studyId: String
    
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
            .map(to: T.self)
            .handleMapError()
    }
    
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?> {
        self.sendShared(request: request, errorType: errorType)
            .mapOptional(to: T.self)
    }
    
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        self.sendShared(request: request, errorType: errorType)
            .map(to: [T].self)
            .catchError({ (error) in
            if let error = error as? ApiError {
                // Network or Server Error
                return Single.error(error)
            } else {
                debugPrint("Response map error: \(error)")
                return Single.error(ApiError.cannotParseData)
            }
        })
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
        .mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
        .handleMapError()
    }
    
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?> {
        self.sendShared(request: request, errorType: errorType)
            .mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
            .handleMapError()
            .catchError { error in
                if case ApiError.cannotParseData = error {
                    return Single.just(nil)
                } else {
                    return Single.error(error)
                }
        }
    }
    
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        self.sendShared(request: request, errorType: errorType)
            .mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
            .handleMapError()
    }
    
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<ExcludeInvalid<T>> {
        self.sendShared(request: request, errorType: errorType)
            .mapCodableJSONAPI(includeList: T.includeList, keyPath: T.keyPath)
            .handleMapError()
    }
    
    func send<T: PlainDecodable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T> {
        self.sendShared(request: request, errorType: errorType)
            .map { response in
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: response.data)
            }
            .handleMapError()
    }
    
    // MARK: - Private Methods
    
    private func sendShared<E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<Response> {
        return self.defaultProvider.rx.request(request.serviceRequest)
            .filterSuccess(api: self, request: request, errorType: errorType)
    }
}

// MARK: - Extension (Single<T>)

fileprivate extension PrimitiveSequence where Trait == SingleTrait {

    func handleMapError() -> Single<Element> {
        return catchError({ (error) -> Single<Element> in
            if let error = error as? ApiError {
                // Network or Server Error
                return Single.error(error)
            } else {
                debugPrint("Response map error: \(error)")
                return Single.error(ApiError.cannotParseData)
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
            .catchError({ (error) -> Single<Response> in
                // Handle network availability
                if api.reachability.isCurrentlyReachable {
                    return Single.error(ApiError.network)
                } else {
                    return Single.error(ApiError.connectivity)
                }
            })
            .flatMap { response -> Single<Element> in
                if 200 ... 299 ~= response.statusCode {
                    // Uncomment this to print the whole response data
                    //                print("Network Body: \(String(data: response.data, encoding: .utf8) ?? "")")
                    self.handleAccessToken(response: response, storage: api.storage)
                    return Single.just(response)
                } else {
                    if response.statusCode >= 500 {
                        return Single.error(ApiError.network)
                    } else if 400 ... 499 ~= response.statusCode {
                        if let serverError = ServerErrorCode(rawValue: response.statusCode) {
                            switch serverError {
                            case .unauthorized:
                                if request.isAuthTokenRequired {
                                    return Single.error(ApiError.userUnauthorized)
                                }
                            }
                        }
                        if let error = try? response.map(to: errorType) {
                            return Single.error(ApiError.error(response.statusCode, error))
                        } else {
                            return Single.error(ApiError.errorCode(response.statusCode, String(data: response.data, encoding: .utf8) ?? ""))
                        }
                    }
                }
                // Its an error and can't decode error details from server, push generic message
                return Single.error(ApiError.network)
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
        // Login
        case .submitPhoneNumber:
            return "/v1/studies/\(studyId)/auth/verify_phone_number"
        case .verifyPhoneNumber:
            return "/v1/studies/\(studyId)/auth/login"
        // Screening Section
        case .getScreeningSection:
            return "/v1/studies/\(studyId)/screening"
        // Informed Consent Section
        case .getInformedConsentSection:
            return "/v1/studies/\(studyId)/informed_consent"
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
        case .createUserConsent, .updateUserConsent:
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
        case .sendTaskResultData(let taskId, _):
            return "v1/tasks/\(taskId)"
        case .sendTaskResultFile(let taskId, _):
            return "v1/tasks/\(taskId)/attach"
        case .delayTask(let taskId):
            return "v1/tasks/\(taskId)/remind"
        // User
        case .getUser:
            return "v1/users/me"
        case .sendUserInfoParameters:
            return "v1/users/me"
        // User Data
        case .getUserData:
            return "v1/studies/\(studyId)/your_data"
        case .getUserDataAggregation(let period):
            return "v1/studies/\(studyId)/user_data_aggregations/\(period.networkValue)"
        // Survey
        case .getSurvey(let surveyId):
            return "v1/survey_group/\(surveyId)"  // TODO: Check against final API specs
        case .sendSurveyTaskResultData(let surveyTaskId, _):
            return "v1/survey/\(surveyTaskId)"  // TODO: Check against final API specs
        }
    }
    
    // Need this to conform to TargetType protocol. getPath(forStudyId) is used instead
    var path: String { "" }
    
    var method: Moya.Method {
        switch self {
        case .getGlobalConfig,
             .getScreeningSection,
             .getInformedConsentSection,
             .getConsentSection,
             .getOptInSection,
             .getUserConsentSection,
             .getIntegrationSection,
             .getStudyInfoSection,
             .getFeeds,
             .getTasks,
             .getSurvey, // TODO: Check against final API specs
             .getUser,
             .getUserData,
             .getUserDataAggregation:
            return .get
        case .submitPhoneNumber,
             .verifyPhoneNumber,
             .createUserConsent,
             .sendOptInPermission,
             .sendAnswer,
             .delayTask:
            return .post
        case .verifyEmail,
             .resendConfirmationEmail,
             .updateUserConsent,
             .sendTaskResultData,
             .sendTaskResultFile,
             .sendUserInfoParameters,
             .sendSurveyTaskResultData: // TODO: Check against final API specs
            return .patch
        }
    }
    
    var sampleData: Data {
        switch self {
        // Misc
        case .getGlobalConfig: return Bundle.getTestData(from: "TestGetGlobalConfig")
        // Login
        case .submitPhoneNumber: return "{}".utf8Encoded
        case .verifyPhoneNumber: return Bundle.getTestData(from: "TestGetUserNoOnboarding")
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
        case .updateUserConsent: return "{}".utf8Encoded
        case .verifyEmail: return "{}".utf8Encoded
        case .resendConfirmationEmail: return "{}".utf8Encoded
        // Integration Section
        case .getIntegrationSection: return Bundle.getTestData(from: "TestGetIntegrationSection")
        //StudyInfo
        case .getStudyInfoSection: return "{}".utf8Encoded
        // Answers
        case .sendAnswer: return "{}".utf8Encoded
        // Task
        case .getFeeds, .getTasks: return Bundle.getTestData(from: "TestGetTasks")
        case .sendTaskResultData: return "{}".utf8Encoded
        case .sendTaskResultFile: return "{}".utf8Encoded
        case .delayTask: return "{}".utf8Encoded
        // User
        case .getUser: return Bundle.getTestData(from: "TestGetUser")
        case .sendUserInfoParameters: return Bundle.getTestData(from: "TestGetUser")
        // User Data
        case .getUserData: return Bundle.getTestData(from: "TestGetUserData")
        case .getUserDataAggregation: return Bundle.getTestData(from: "TestGetUserDataAggregation")
        // Survey
        case .getSurvey: return Bundle.getTestData(from: "TestGetSurvey")
        case .sendSurveyTaskResultData: return "{}".utf8Encoded
        }
    }
    
    var task: Task {
        switch self {
        case .getGlobalConfig,
             .getScreeningSection,
             .getInformedConsentSection,
             .getConsentSection,
             .getOptInSection,
             .getStudyInfoSection,
             .getUserConsentSection,
             .resendConfirmationEmail,
             .getIntegrationSection,
             .getFeeds,
             .getTasks,
             .getSurvey,
             .getUser,
             .getUserData,
             .getUserDataAggregation,
             .delayTask:
            return .requestPlain
        case .submitPhoneNumber(let phoneNumber):
            var params: [String: Any] = [:]
            params["phone_number"] = phoneNumber
            return .requestParameters(parameters: ["user": params], encoding: JSONEncoding.default)
        case .verifyPhoneNumber(let phoneNumber, let secureCode):
            var params: [String: Any] = [:]
            params["phone_number"] = phoneNumber
            params["verification_code"] = secureCode
            return .requestParameters(parameters: ["user": params], encoding: JSONEncoding.default)
        case let .createUserConsent(email, firstName, lastName, signatureImage):
            return Task.createForUserContent(withEmail: email,
                                             firstName: firstName,
                                             lastName: lastName,
                                             signatureImage: signatureImage,
                                             isCreate: true)
        case let .updateUserConsent(email, firstName, lastName, signatureImage):
            return Task.createForUserContent(withEmail: email,
                                             firstName: firstName,
                                             lastName: lastName,
                                             signatureImage: signatureImage,
                                             isCreate: false)
        case .verifyEmail(let email):
            var params: [String: Any] = [:]
            params["email_confirmation_token"] = email
            return .requestParameters(parameters: ["user_consent": params], encoding: JSONEncoding.default)
        case .sendOptInPermission(_, let granted, let context):
            var params: [String: Any] = [:]
            params["agree"] = granted
            params.addContext(context)
            return .requestParameters(parameters    : ["user_permission": params], encoding: JSONEncoding.default)
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
        case .sendSurveyTaskResultData(_, let results):
            // TODO: Update request encoding according to API specs
            let params: [[String: Any]] = results.reduce([]) { (result, parameter) in
                var result = result
                var userParameter: [String: Any] = [:]
                userParameter["question_id"] = parameter.question.id
                userParameter["answer"] = parameter.answer
                result.append(userParameter)
                return result
            }
            return .requestParameters(parameters: ["answers": params], encoding: JSONEncoding.default)
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
             .submitPhoneNumber,
             .verifyPhoneNumber:
            return nil
        case .getScreeningSection,
             .getInformedConsentSection,
             .getConsentSection,
             .getOptInSection,
             .sendOptInPermission,
             .getUserConsentSection,
             .createUserConsent,
             .updateUserConsent,
             .getStudyInfoSection,
             .verifyEmail,
             .resendConfirmationEmail,
             .getIntegrationSection,
             .sendAnswer,
             .getFeeds,
             .getTasks,
             .sendTaskResultData,
             .sendTaskResultFile,
             .sendUserInfoParameters,
             .getSurvey,
             .sendSurveyTaskResultData,
             .getUser,
             .getUserData,
             .getUserDataAggregation,
             .delayTask:
            return .bearer
        }
    }
}

fileprivate extension Task {
    static func createForUserContent(withEmail email: String?,
                                     firstName: String?,
                                     lastName: String?,
                                     signatureImage: UIImage?,
                                     isCreate: Bool) -> Task {
        var params: [String: Any] = [:]
        if isCreate {
            params["agree"] = true
        }
        if let email = email {
            params["new_email"] = email
        }
        if let firstName = firstName {
            params["first_name"] = firstName
        }
        if let lastName = lastName {
            params["last_name"] = lastName
        }
        if let signatureImage = signatureImage {
            if let imageData = signatureImage.pngData() {
                var imageDataString = imageData.base64EncodedString()
                // Mime type
                imageDataString = "data:image/png;base64,\(imageDataString)"
                params["signature_base64"] = imageDataString
            } else {
                assertionFailure("Cannot image to PNG")
            }
        }
        return .requestParameters(parameters: ["user_consent": params], encoding: JSONEncoding.default)
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
        }
    }
    var mimeType: String {
        switch self {
        case .mp4: return "video/mp4"
        }
    }
}

fileprivate extension StudyPeriod {
    var networkValue: String {
        switch self {
        case .week: return "last_week"
        case .month: return "last_month"
        case .year: return "last_year"
        }
    }
}
