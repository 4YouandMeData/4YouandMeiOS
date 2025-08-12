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
    var infoMessages: [MessageInfo]? { get set }
    var feedbackList: [String: [EmojiItem]] {get set}
}

class RepositoryImpl {
    
    // InitializableService
    var isInitialized: Bool = false
    
    var study: Study?
    
    private let api: ApiGateway
    private var storage: RepositoryStorage
    private let notificationService: NotificationService
    private let analyticsService: AnalyticsService
    private let showDefaultUserInfo: Bool
    private let appleWatchAlternativeIntegrations: [Integration]
    
    private let disposeBag = DisposeBag()
    
    init(api: ApiGateway,
         storage: RepositoryStorage,
         notificationService: NotificationService,
         analyticsService: AnalyticsService,
         showDefaultUserInfo: Bool,
         appleWatchAlternativeIntegrations: [Integration]) {
        self.api = api
        self.storage = storage
        self.notificationService = notificationService
        self.analyticsService = analyticsService
        self.showDefaultUserInfo = showDefaultUserInfo
        self.appleWatchAlternativeIntegrations = appleWatchAlternativeIntegrations
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
                self.storage.feedbackList = globalConfig.feedbackList ?? [:]
            })
            .toVoid()
    }
    
    private func fetchStudy() -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .getStudy))
            .do(onSuccess: { self.study = $0 })
            .handleError()
            .toVoid()
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
    
    var currentUserPhase: UserPhase? {
        guard let userPhases = self.currentUser?.userPhases else {
            return nil
        }
        let sortedUserPhases = userPhases.sort(byNames: self.phaseNames)
        return sortedUserPhases.first(where: { $0.endAt == nil }) ?? sortedUserPhases.last
    }
    
    var currentPhaseIndex: PhaseIndex? {
        guard let currentUserPhase = self.currentUserPhase else {
            return nil
        }
        return self.phaseNames.firstIndex(of: currentUserPhase.phase.name)
    }
    
    var phaseNames: [String] {
        return self.storage.globalConfig?.phaseNames ?? []
    }
    
    func logOut() {
        self.storage.user = nil
        self.api.logOut()
    }
    
    var infoMessages: [MessageInfo]? {
        return self.storage.infoMessages
    }
    
    func sendFirebaseToken(token: String) -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendPushToken(token: token)))
            .handleError()
            .do(onError: { error in print("Repository - error updateFirebaseToken: \(error.localizedDescription)") })
    }
#if HEALTHKIT
    func getTerraToken() -> Single<TerraTokenResponse> {
        self.api.send(request: ApiRequest(serviceRequest: .getTerraToken))
            .handleError()
    }
#endif
    
    enum SubmitPhoneNumberErrorCode: Int, CaseIterable { case missingPhoneNumber = 404 }
    
    func submitPhoneNumber(phoneNumber: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .submitPhoneNumber(phoneNumber: phoneNumber)))
            .handleError()
            .catch({ error -> Single<()> in
                
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
            .catch({ error -> Single<(User)> in
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
            .catch({ (error)-> Single<(User)> in
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
    
    // MARK: - Onboarding Section
    
    func submitProfilingOption(questionId: String, optionId: Int) -> Single<()> {
        return self.api.send(request:
                                ApiRequest(serviceRequest: .submitProfilingOption(questionId: questionId,
                                                                                  optionId: optionId)))
    }
    
    // MARK: - Screening
    
    func getScreeningSection() -> Single<ScreeningSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getScreeningSection))
            .handleError()
    }
    
    // MARK: - Informed Consent
    
    func getOnboardingQuestionsSection() -> Single<OnboardingQuestionsSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getOnboardingQuestionsSection))
    }
    
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
        return self.refreshUser()
            .flatMap { _ -> Single<ConsentUserDataSection> in
                return self.api.send(request: ApiRequest(serviceRequest: .getUserConsentSection))
                    .handleError()
            }
    }
    
    func submitEmail(email: String) -> Single<()> {
        let data = UserConsentData(
            email: email,
            firstName: nil,
            lastName: nil,
            guardianFirstName: nil,
            guardianLastName: nil,
            relation: nil,
            signatureImage: nil,
            additionalImage: nil,
            isCreate: false)
        return self.api.send(request: ApiRequest(serviceRequest:
                .createUserConsent(userConsentData: data)))
            .handleError()
    }
    
    // MARK: - Study Info Section
    
    func getStudyInfoSection() -> Single<StudyInfoSection> {
        return self.api.send(request: ApiRequest(serviceRequest: .getStudyInfoSection))
            .map { (studyInfoSection: StudyInfoSection) in
                var studyInfoSection = studyInfoSection
                if let phaseIndex = self.currentPhaseIndex, let phaseFaqPage = self.getPhase(forPhaseIndex: phaseIndex)?.faqPage {
                    studyInfoSection.faqPage = phaseFaqPage
                }
                return studyInfoSection
            }
            .handleError()
    }
    
    enum VerifyEmailErrorCode: Int, CaseIterable { case wrongValidationCode = 422 }
    
    func verifyEmail(validationCode: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .verifyEmail(validationCode: validationCode)))
            .handleError()
            .catch({ error -> Single<()> in
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
    
    func sendUserData(userConsentData consentData: UserConsentData) -> Single<UserConsent> {
        return self.api.send(request: ApiRequest(serviceRequest:
                .createUserConsent(userConsentData: consentData)))
            .handleError()
    }
    
    func sendUserDataForMinor(consentId: String, userConsentData: UserConsentData) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest:
                .createOtherUserConsent(consentId: consentId, userConsentData: userConsentData)))
            .handleError()
    }
    
    func sendWalkthroughDone() -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendWalthroughDone))
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
    
    func sendQuickActivityResult(quickActivityTaskId: String, quickActivityOption: QuickActivityOption, optionalFlag: Bool) -> Single<()> {
        let resultData = quickActivityOption.networkResultData.data
        return self.api.send(request: ApiRequest(serviceRequest: .sendTaskResultData(taskId: quickActivityTaskId,
                                                                                     resultData: resultData,
                                                                                     optionalFlag: optionalFlag)))
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
    
    func sendSkipTask(taskId: String) -> Single<()> {
        self.api.send(request: ApiRequest(serviceRequest: .sendSkipTask(taskId: taskId))).handleError()
    }
    
    func delayTask(taskId: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .delayTask(taskId: taskId)))
            .handleError()
    }
    
    func getDiaryNotes(diaryNote: DiaryNoteItem?, fromChart: Bool) -> Single<[DiaryNoteItem]> {
        return self.api.send(request: ApiRequest(serviceRequest: .getDiaryNotes(diaryNote: diaryNote, fromChart: fromChart)))
            .handleError()
    }
    
    func getDiaryNoteText(noteID: String) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest: .getDiaryNoteText(noteId: noteID)))
            .handleError()
    }
    
    func getDiaryNoteAudio(noteID: String) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest: .getDiaryNoteAudio(noteId: noteID)))
            .handleError()
    }
    
    func sendDiaryNoteText(diaryNote: DiaryNoteItem, fromChart: Bool) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendDiaryNoteText(diaryItem: diaryNote, fromChart: fromChart)))
            .handleError()
    }
    
    func sendDiaryNoteAudio(diaryNoteRef: DiaryNoteItem, file: DiaryNoteFile, fromChart: Bool) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest:
                .sendDiaryNoteAudio(noteId: diaryNoteRef,
                                    attachment: file,
                                    fromChart: fromChart)))
            .handleError()
    }
    
    func sendDiaryNoteVideo(diaryNoteRef: DiaryNoteItem, file: DiaryNoteFile) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest:
                .sendDiaryNoteVideo(noteId: diaryNoteRef,
                                    attachment: file)))
            .handleError()
    }
    
    func sendDiaryNoteEaten(date: Date,
                            mealType: String,
                            quantity: String,
                            significantNutrition: Bool,
                            fromChart: Bool,
                            diaryNote: DiaryNoteItem?) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest:
                .sendDiaryNoteEaten(date: date,
                                    mealType: mealType,
                                    quantity: quantity,
                                    significantNutrition: significantNutrition,
                                    fromChart: fromChart,
                                    diaryNote: diaryNote)))
            .handleError()
    }
    
    func sendDiaryNoteDoses(doseType: String,
                            date: Date,
                            amount: Double,
                            fromChart: Bool,
                            diaryNote: DiaryNoteItem?) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest:
                .sendDiaryNoteDoses(
                    doseType: doseType,
                    date: date,
                    amount: amount,
                    fromChart: fromChart,
                    diaryNote: diaryNote)))
        .handleError()
    }
    
    func sendCombinedDiaryNote(diaryNote: DiaryNoteWeHaveNoticedItem) -> Single<DiaryNoteItem> {
        return self.api.send(request: ApiRequest(serviceRequest:
                .sendCombinedDiaryNote(diaryNote: diaryNote)))
        .handleError()
    }

    func updateDiaryNoteText(diaryNote: DiaryNoteItem) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .updateDiaryNoteText(diaryItem: diaryNote)))
            .handleError()
    }
    
    func deleteDiaryNote(noteID: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .deleteDiaryNote(noteId: noteID)))
            .handleError()
    }
    
    func sendSpyroResults(results: [String: Any]) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendSpyroResults(results: results)))
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
            .flatMap { user in self.sanitizePhase().map { user } }
    }
    
    func sendUserInfoParameters(userParameterRequests: [UserInfoParameterRequest]) -> Single<User> {
        let oldUserInfoParameters = self.currentUser?.customData ?? []
        return self.sharedSendUserInfoParameters(userParameterRequests: userParameterRequests)
            .flatMap { user in
                let newUserInfoParameters = user.customData ?? []
                let changedUserInfoParameters = Self.getChangedUserInfoParameters(oldUserInfoParameters: oldUserInfoParameters,
                                                                                  newUserInfoParameters: newUserInfoParameters)
                // The absense of phase could be due to the absense of phases in the study
                // or because of an incoherence. In the former case, we skip the phase logic,
                // while in the latter we rely on the subsequent sanitizePhase method to try
                // to resolve the incoherence
                if let currentUserPhase = self.currentUserPhase, changedUserInfoParameters.count > 0 {
                    var request = Single.just(())
                    for userParameterRequest in changedUserInfoParameters {
                        // Change phase only if the current parameter has a phase index and a not nil and not empty value is set
                        if let phaseIndex = userParameterRequest.phaseIndex, userParameterRequest.value.nilIfEmpty != nil {
                            // Throw an error if phase index cannot be converted to a phase to a phase name
                            if let phase = self.getPhase(forPhaseIndex: phaseIndex) {
                                request = request.flatMap { () in
                                    return self
                                        .updateUserPhase(userPhaseId: currentUserPhase.id)
                                        .flatMap { self.createUserPhase(phaseId: phase.id) }
                                }
                            } else {
                                return Single.error(RepositoryError.remoteServerError)
                            }
                        }
                    }
                    return request
                        .catch { error in self.sanitizePhase().flatMap { Single.error(error) } }
                        .flatMap { self.refreshUser() }
                } else {
                    return Single.just(user)
                }
            }
    }
    
    // MARK: - User Data
    
    func getUserData() -> Single<UserData> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUserData))
            .handleError()
    }
    
    func getUserSettings() -> Single<(UserSettings)> {
        return self.api.send(request: ApiRequest(serviceRequest: .getUserSettings))
            .handleError()
    }
    
    func sendUserSettings(seconds: Int?, notificationTime: Int?) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendUserSettings(settings: seconds,
                                                                                   notificationTime: notificationTime)))
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
    
    func getInfoMessages() -> Single<[MessageInfo]> {
        return self.api.send(request: ApiRequest(serviceRequest: .getInfoMessages)).handleError()
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
                .catchAndReturn(user)
        } else {
            return Single.just(user)
        }
    }
    
    private func handleUserInfo(_ user: User) -> User {
        var user = user
        if self.showDefaultUserInfo {
            var customData = user.customData ?? []
            let defaultData = Constants.UserInfo.DefaultUserInfoParameters
            let missingCustomData = defaultData.filter { !customData.contains($0) }
            customData.append(contentsOf: missingCustomData)
            customData.sort { userDataParameter1, userDataParameter2 in
                defaultData.firstIndex(of: userDataParameter1) ?? 0 < defaultData.firstIndex(of: userDataParameter2) ?? 0
            }
            user.customData = customData
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
            .catchAndReturn(user)
    }
    
    private func saveUser(_ user: User) {
        self.storage.user = user
    }
    
    private static func getChangedUserInfoParameters(
        oldUserInfoParameters: [UserInfoParameter],
        newUserInfoParameters: [UserInfoParameter]
    ) -> [UserInfoParameter] {
        return newUserInfoParameters.reduce([]) { changedUserInfoParameters, newUserInfoParameter in
            var changedUserInfoParameters = changedUserInfoParameters
            if let oldUserInfoParameter = oldUserInfoParameters
                .first(where: { newUserInfoParameter.identifier == $0.identifier }) {
                if oldUserInfoParameter.value != newUserInfoParameter.value {
                    changedUserInfoParameters.append(newUserInfoParameter)
                }
            } else {
                changedUserInfoParameters.append(newUserInfoParameter)
            }
            return changedUserInfoParameters
        }
    }
    
    private func getPhase(forPhaseIndex phaseIndex: PhaseIndex) -> Phase? {
        guard phaseIndex >= 0, phaseIndex < self.phaseNames.count else {
            return nil
        }
        return self.study?.phases?.getPhase(withName: self.phaseNames[phaseIndex])
    }
    
    private func sharedSendUserInfoParameters(userParameterRequests: [UserInfoParameterRequest]) -> Single<User> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendUserInfoParameters(paramenters: userParameterRequests)))
            .handleError()
            .map { self.handleUserInfo($0) }
            .do(onSuccess: { self.saveUser($0) })
    }
    
    private func createUserPhase(phaseId: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .createUserPhase(phaseId: phaseId)))
            .handleError()
    }
    
    private func updateUserPhase(userPhaseId: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .updateUserPhase(userPhaseId: userPhaseId)))
            .handleError()
    }
    
    private func sanitizePhase() -> Single<()> {
        // This is currently super-specific for the Bump study.
        // TODO: Generalize!!!!
        // If the delivery date is set, but we are in 'Pre-delivery' phase,
        // remove the post-delivery entry from custom data.
        let deliveryDateUserInfoParameter = self.currentUser?.customData?
            .first(where: { $0.identifier == Constants.UserInfo.PostDeliveryParameterIdentifier })
        if self.currentPhaseIndex == Constants.UserInfo.PreDeliveryPhaseIndex,
           deliveryDateUserInfoParameter?.value.nilIfEmpty != nil {
            let userParameterRequests: [UserInfoParameterRequest] = (self.currentUser?.customData ?? [])
                .reduce([]) { userParameterRequests, userInfoParameter in
                    var userParameterRequests = userParameterRequests
                    if userInfoParameter.identifier != Constants.UserInfo.PostDeliveryParameterIdentifier {
                        userParameterRequests.append(UserInfoParameterRequest(parameter: userInfoParameter,
                                                                              value: userInfoParameter.value))
                    }
                return userParameterRequests
            }
            return self.sharedSendUserInfoParameters(userParameterRequests: userParameterRequests)
                .toVoid()
                .do(onSuccess: { debugPrint("Repository - Phase Sanitization Successful") })
                .do(onError: { error in debugPrint("Repository - Phase Sanitization Failed. Error: \(error.localizedDescription)") })
                .catchAndReturn(())
        } else {
            return Single.just(())
                .do(onSuccess: { debugPrint("Repository - Phase Sanitization Not Needed") })
        }
    }
}

extension RepositoryImpl: NotificationTokenDelegate {
    func registerNotificationToken(token: String) {
        if self.isLoggedIn {
            self.sendFirebaseToken(token: token)
                .subscribe { _ in
                    print("RepositoryImpl - Sent Registration Token to server due to token update")
                } onFailure: { error in
                    print("RepositoryImpl - Error while sending Registration Token to server due to token update. Error: \(error)")
                }.disposed(by: self.disposeBag)
        }
    }
}

// MARK: - HealthManagerNetworkDelegate

extension RepositoryImpl: HealthManagerNetworkDelegate {
    func uploadHealthNetworkData(_ healthNetworkData: HealthNetworkData, source: String) -> Single<()> {
        return self.api.send(request: ApiRequest(serviceRequest: .sendHealthData(healthData: healthNetworkData, source: source)))
            .handleError()
            .catch { error in
                guard let repositoryError = error as? RepositoryError else {
                    assertionFailure("Unexpected error type")
                    return Single.error(error)
                }
                switch repositoryError {
                case .connectivityError: return Single.error(HealthSampleUploaderError.uploadConnectivityError)
                default: return Single.error(HealthSampleUploaderError.uploadServerError(underlyingError: error))
                }
            }
    }
}

// MARK: - HealthManagerClearanceDelegate

extension RepositoryImpl: HealthManagerClearanceDelegate {
    var healthManagerCanRun: Bool { self.currentUser?.getHasAgreedTo(systemPermission: .health) ?? false }
}

// MARK: - Extension(PrimitiveSequence)

fileprivate extension PrimitiveSequence where Trait == SingleTrait {
    func handleError(debugMode: Bool = false) -> Single<Element> {
        return self.handleServerError(debugMode: debugMode)
    }
    
    func handleServerError(debugMode: Bool = false) -> Single<Element> {
        return self.catch({ (error) -> Single<Element> in
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
        
        var requests = Single<()>.zip([self.fetchGlobalConfig(), self.fetchStudy()]).toVoid()
        
        if self.isLoggedIn {
            requests = requests.flatMap {
                self.refreshUser()
                    .toVoid()
                    .catchAndReturn(())
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
