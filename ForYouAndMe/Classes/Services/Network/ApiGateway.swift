//
//  ApiGateway.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import RxSwift

typealias TaskNetworkResultData = [String: Any]
struct TaskNetworkResultFile {
    let data: Data
    let fileExtension: FileDataExtension
}

enum DefaultService {
    // Misc
    case getGlobalConfig
    case getStudy
    // Login
    case submitPhoneNumber(phoneNumber: String)
    case verifyPhoneNumber(phoneNumber: String, validationCode: String)
    case emailLogin(email: String)
    // Oboarding Section
    case submitProfilingOption(questionId: String, optionId: Int)
    // Screening Section
    case getScreeningSection
    // Informed Consent Section
    case getInformedConsentSection
    case getOnboardingQuestionsSection
    // Consent Section
    case getConsentSection
    // Opt In Section
    case getOptInSection
    case sendOptInPermission(permissionId: String, granted: Bool, context: ApiContext?)
    // User Consent Section
    case getUserConsentSection
    case createUserConsent(userConsentData: UserConsentData)
    case createOtherUserConsent(consentId: String, userConsentData: UserConsentData)
    case updateUserConsent(userConsentData: UserConsentData)
    case notifyOnboardingCompleted
    case verifyEmail(validationCode: String)
    case resendConfirmationEmail
    // Study Info Section
    case getStudyInfoSection
    // Integration Section
    case getIntegrationSection
    // Answer
    case sendAnswer(answer: Answer, context: ApiContext?)
    // Feed
    case getFeeds(paginationInfo: PaginationInfo?)
    // Task
    case getTasks(paginationInfo: PaginationInfo?)
    case getTask(taskId: String)
    case sendTaskResultData(taskId: String, resultData: TaskNetworkResultData)
    case sendTaskResultFile(taskId: String, resultFile: TaskNetworkResultFile)
    case delayTask(taskId: String)
    case getDiaryNotes(diaryNote: DiaryNoteItem?, fromChart: Bool)
    case getDiaryNoteText(noteId: String)
    case getDiaryNoteAudio(noteId: String)
    case sendDiaryNoteText(diaryItem: DiaryNoteItem, fromChart: Bool)
    case updateDiaryNoteText(diaryItem: DiaryNoteItem)
    case sendDiaryNoteAudio(noteId: DiaryNoteItem, attachment: DiaryNoteFile, fromChart: Bool)
    case sendDiaryNoteVideo(noteId: DiaryNoteItem, attachment: DiaryNoteFile)
    case sendDiaryNoteEaten(date: Date, mealType: String, quantity: String, significantNutrition: Bool, fromChart: Bool)
    case deleteDiaryNote(noteId: String)
    case sendSpyroResults(results: [String: Any])
    // User
    case getUser
    case sendUserInfoParameters(paramenters: [UserInfoParameterRequest])
    case sendUserTimeZone(timeZoneIdentifier: String)
    case sendPushToken(token: String)
    case sendWalthroughDone
    // User Data
    case getUserData
    case getUserSettings
    case sendUserSettings(settings: Int)
    // Survey
    case getSurvey(surveyId: String)
    case sendSurveyTaskResultData(surveyTaskId: String, results: [SurveyResult])
    // Device Data
    case sendDeviceData(deviceData: DeviceData)
    // Health
    case sendHealthData(healthData: HealthNetworkData, source: String)
    // User Phase
    case createUserPhase(phaseId: String)
    case updateUserPhase(userPhaseId: String)
    // Info Message
    case getInfoMessages
}

struct ApiRequest {
    
    let serviceRequest: DefaultService
    
    init(serviceRequest: DefaultService) {
        self.serviceRequest = serviceRequest
    }
}

enum ApiError: Error {
    case connectivity
    case cannotParseData(pathUrl: String, request: ApiRequest, statusCode: Int, responseBody: String)
    case network(pathUrl: String, request: ApiRequest, underlyingError: Error)
    case unexpectedError(pathUrl: String, request: ApiRequest, statusCode: Int, responseBody: String)
    case expectedError(pathUrl: String, request: ApiRequest, statusCode: Int, responseBody: String, parsedError: Any)
    case userUnauthorized(pathUrl: String, request: ApiRequest, statusCode: Int, responseBody: String)
}

protocol PlainDecodable: Decodable {}

protocol ApiGateway {
    
    func send<E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<()>
    
    // Mappable entities (Model Mapper)
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T>
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?>
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]>
    func sendExcludeInvalid<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]>
    
    // JSONAPIMappable entities (Japx)
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T>
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?>
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]>
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<ExcludeInvalid<T>>
    
    // Decodable entities
    func send<T: PlainDecodable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T>
    
    var accessToken: String? { get }
    func isLoggedIn() -> Bool
    func logOut()
}

extension ApiGateway {
    func send(request: ApiRequest) -> Single<()> {
        return self.send(request: request, errorType: ResponseError.self)
    }
    
    // Mappable entities (Model Mapper)
    func send<T: Mappable>(request: ApiRequest) -> Single<T> {
        return self.send(request: request, errorType: ResponseError.self)
    }

    func send<T: Mappable>(request: ApiRequest) -> Single<T?> {
        return self.send(request: request, errorType: ResponseError.self)
    }

    func send<T: Mappable>(request: ApiRequest) -> Single<[T]> {
        return self.send(request: request, errorType: ResponseError.self)
    }

    func sendExcludeInvalid<T: Mappable>(request: ApiRequest) -> Single<[T]> {
        return self.sendExcludeInvalid(request: request, errorType: ResponseError.self)
    }
    
    // JSONAPIMappable entities (Japx)
    func send<T: JSONAPIMappable>(request: ApiRequest) -> Single<T> {
        return self.send(request: request, errorType: ResponseError.self)
    }
    
    func send<T: JSONAPIMappable>(request: ApiRequest) -> Single<T?> {
        return self.send(request: request, errorType: ResponseError.self)
    }
    
    func send<T: JSONAPIMappable>(request: ApiRequest) -> Single<[T]> {
        return self.send(request: request, errorType: ResponseError.self)
    }
    
    func send<T: JSONAPIMappable>(request: ApiRequest) -> Single<ExcludeInvalid<T>> {
        return self.send(request: request, errorType: ResponseError.self)
    }
    
    // Decodable entities
    func send<T: PlainDecodable>(request: ApiRequest) -> Single<T> {
        return self.send(request: request, errorType: ResponseError.self)
    }
}
