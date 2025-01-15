//
//  Repository.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

enum RepositoryError: LocalizedError {
    // Authentication
    case userNotLoggedIn
    
    // Server
    case remoteServerError
    case serverErrorSpecific(error: Any)
    
    // Login
    case missingPhoneNumber
    case wrongPhoneValidationCode
    
    // Onboarding
    case wrongEmailValidationCode
    
    // Shared
    case connectivityError
    case genericError
    
    // Debug Only - To be used only when showing full error details to the
    // user is really necessary (e.g. when Apple reviewers have unreproducable issues)
    case debugError(error: NSError)
}

enum FetchMode {
    case refresh(pageSize: Int?)
    case append(paginationInfo: PaginationInfo)
}

struct PaginationInfo {
    let pageSize: Int
    let pageIndex: Int
}

protocol Repository: AnyObject {
    // Authentication
    var accessToken: String? { get }
    var isLoggedIn: Bool { get }
    var isPinCodeLogin: Bool? { get }
    var currentPhaseIndex: PhaseIndex? { get }
    var currentUserPhase: UserPhase? { get }
    var phaseNames: [String] { get }
    func logOut()
    func submitPhoneNumber(phoneNumber: String) -> Single<()>
    func verifyPhoneNumber(phoneNumber: String, validationCode: String) -> Single<User>
    func emailLogin(email: String) -> Single<User>
    // Screening Section
    func getScreeningSection() -> Single<ScreeningSection>
    // Informed Consent Section
    func getInformedConsentSection() -> Single<InformedConsentSection>
    // Consent Section
    func getConsentSection() -> Single<ConsentSection>
    // Opt In Section
    func getOptInSection() -> Single<OptInSection>
    func sendOptInPermission(permission: OptInPermission, granted: Bool) -> Single<()>
    // User Consent Section
    func getUserConsentSection() -> Single<ConsentUserDataSection>
    func submitEmail(email: String) -> Single<()>
    func verifyEmail(validationCode: String) -> Single<()>
    func resendConfirmationEmail() -> Single<()>
    func sendUserData(firstName: String, lastName: String, signatureImage: UIImage) -> Single<()>
    func notifyOnboardingCompleted() -> Single<()>
    // Integration Section
    func getIntegrationSection() -> Single<IntegrationSection>
    // Tasks
    func getFeeds(fetchMode: FetchMode) -> Single<[Feed]>
    func getTasks(fetchMode: FetchMode) -> Single<[Feed]>
    func getTask(taskId: String) -> Single<Feed>
    func sendQuickActivityResult(quickActivityTaskId: String, quickActivityOption: QuickActivityOption) -> Single<()>
    func sendTaskResult(taskId: String, taskResult: TaskNetworkResult) -> Single<()>
    func delayTask(taskId: String) -> Single<()>
    func getDiaryNotes(diaryNote: DiaryNoteItem?, fromChart: Bool) -> Single<[DiaryNoteItem]>
    func getDiaryNoteText(noteID: String) -> Single<DiaryNoteItem>
    func getDiaryNoteAudio(noteID: String) -> Single<DiaryNoteItem>
    func sendDiaryNoteText(diaryNote: DiaryNoteItem, fromChart: Bool) -> Single<()>
    func sendDiaryNoteAudio(diaryNoteRef: DiaryNoteItem, file: DiaryNoteFile, fromChart: Bool) -> Single<DiaryNoteItem>
    func updateDiaryNoteText(diaryNote: DiaryNoteItem) -> Single<()>
    func deleteDiaryNote(noteID: String) -> Single<()>
    // User
    var currentUser: User? { get }
    func refreshUser() -> Single<User>
    func sendUserInfoParameters(userParameterRequests: [UserInfoParameterRequest]) -> Single<User>
    // User Data
    func getUserData() -> Single<UserData>
    func getUserSettings() -> Single<UserSettings>
    func sendUserSettings(seconds: Int) -> Single<()>
    // Survey
    func getSurvey(surveyId: String) -> Single<SurveyGroup>
    func sendSurveyTaskResult(surveyTaskId: String, results: [SurveyResult]) -> Single<()>
    // StudyInfo
    func getStudyInfoSection() -> Single<StudyInfoSection>
    // Device Data
    func sendDeviceData(deviceData: DeviceData) -> Single<()>
    //Info Messages
    func getInfoMessages() -> Single<[MessageInfo]>
}
