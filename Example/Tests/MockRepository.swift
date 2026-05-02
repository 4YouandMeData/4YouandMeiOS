//
//  MockRepository.swift
//  ForYouAndMe_Tests
//
//  Test double implementing the full Repository protocol.
//  Methods used by Hot Flash flow capture inputs and return injectable Singles.
//  All other methods return Single.never() so unrelated paths don't crash tests
//  but accidental usage is observable (the test will hang if a path is unexpectedly hit).
//

import Foundation
import RxSwift
@testable import ForYouAndMe

final class MockRepository: Repository {

    // MARK: - Recorded inputs
    private(set) var sendDiaryNoteHotFlashCallCount = 0
    private(set) var lastSentHotFlashData: DiaryNoteHotFlashData?

    private(set) var updateDiaryNoteTextCallCount = 0
    private(set) var lastUpdatedDiaryNote: DiaryNoteItem?

    private(set) var sendQuickActivityResultCallCount = 0
    private(set) var lastQuickActivityTaskId: String?
    private(set) var lastQuickActivityOption: QuickActivityOption?

    private(set) var getTaskCallCount = 0
    private(set) var lastRequestedTaskId: String?

    // MARK: - Stubbed responses
    var hotFlashResult: Single<DiaryNoteItem> = .never()
    var updateDiaryNoteTextResult: Single<()> = .just(())
    var quickActivityResultResponse: Single<QuickActivityResultResponse> = .just(QuickActivityResultResponse(taskId: nil))
    var getTaskResult: Single<Feed> = .never()

    // MARK: - Hot Flash methods (under test)
    func sendDiaryNoteHotFlash(data: DiaryNoteHotFlashData) -> Single<DiaryNoteItem> {
        sendDiaryNoteHotFlashCallCount += 1
        lastSentHotFlashData = data
        return hotFlashResult
    }

    func updateDiaryNoteText(diaryNote: DiaryNoteItem) -> Single<()> {
        updateDiaryNoteTextCallCount += 1
        lastUpdatedDiaryNote = diaryNote
        return updateDiaryNoteTextResult
    }

    // MARK: - Auth / config (unused by hot flash flow)
    var accessToken: String? = nil
    var isLoggedIn: Bool = false
    var isPinCodeLogin: Bool? = nil
    var currentPhaseIndex: PhaseIndex? = nil
    var currentUserPhase: UserPhase? = nil
    var phaseNames: [String] = []
    var currentUser: User? = nil

    func logOut() {}
    func submitPhoneNumber(phoneNumber: String) -> Single<()> { .never() }
    func verifyPhoneNumber(phoneNumber: String, validationCode: String) -> Single<User> { .never() }
    func emailLogin(email: String) -> Single<User> { .never() }

    // Always implemented because the ForYouAndMe framework is compiled with
    // HEALTHKIT, so the imported Repository protocol always exposes this method.
    func getTerraToken() -> Single<TerraTokenResponse> { .never() }

    func submitProfilingOption(questionId: String, optionId: Int) -> Single<()> { .never() }
    func getScreeningSection() -> Single<ScreeningSection> { .never() }
    func getInformedConsentSection() -> Single<InformedConsentSection> { .never() }
    func getOnboardingQuestionsSection() -> Single<OnboardingQuestionsSection> { .never() }
    func getConsentSection() -> Single<ConsentSection> { .never() }
    func getOptInSection() -> Single<OptInSection> { .never() }
    func sendOptInPermission(permission: OptInPermission, granted: Bool) -> Single<()> { .never() }
    func getUserConsentSection() -> Single<ConsentUserDataSection> { .never() }
    func submitEmail(email: String) -> Single<()> { .never() }
    func verifyEmail(validationCode: String) -> Single<()> { .never() }
    func resendConfirmationEmail() -> Single<()> { .never() }
    func sendUserData(userConsentData: UserConsentData) -> Single<UserConsent> { .never() }
    func sendUserDataForMinor(consentId: String, userConsentData: UserConsentData) -> Single<()> { .never() }
    func sendWalkthroughDone() -> Single<()> { .never() }
    func notifyOnboardingCompleted() -> Single<()> { .never() }
    func getIntegrationSection() -> Single<IntegrationSection> { .never() }

    func getFeeds(fetchMode: FetchMode) -> Single<[Feed]> { .never() }
    func getTasks(fetchMode: FetchMode) -> Single<[Feed]> { .never() }
    func getTask(taskId: String) -> Single<Feed> {
        getTaskCallCount += 1
        lastRequestedTaskId = taskId
        return getTaskResult
    }
    func sendQuickActivityResult(quickActivityTaskId: String, quickActivityOption: QuickActivityOption, optionalFlag: Bool) -> Single<QuickActivityResultResponse> {
        sendQuickActivityResultCallCount += 1
        lastQuickActivityTaskId = quickActivityTaskId
        lastQuickActivityOption = quickActivityOption
        return quickActivityResultResponse
    }
    func sendSkipTask(taskId: String) -> Single<()> { .never() }
    func sendTaskResult(taskId: String, taskResult: TaskNetworkResult) -> Single<()> { .never() }
    func delayTask(taskId: String) -> Single<()> { .never() }

    func getDiaryNotes(diaryNote: DiaryNoteItem?, fromChart: Bool) -> Single<[DiaryNoteItem]> { .never() }
    func getDiaryNoteText(noteID: String) -> Single<DiaryNoteItem> { .never() }
    func getDiaryNoteAudio(noteID: String) -> Single<DiaryNoteItem> { .never() }
    func sendDiaryNoteText(diaryNote: DiaryNoteItem, fromChart: Bool) -> Single<DiaryNoteItem> { .never() }
    func sendDiaryNoteAudio(diaryNoteRef: DiaryNoteItem, file: DiaryNoteFile, fromChart: Bool) -> Single<DiaryNoteItem> { .never() }
    func sendDiaryNoteVideo(diaryNoteRef: DiaryNoteItem, file: DiaryNoteFile) -> Single<DiaryNoteItem> { .never() }
    func sendDiaryNoteEaten(data: DiaryNoteEatenData) -> Single<DiaryNoteItem> { .never() }
    func sendDiaryNoteDoses(doseType: String, date: Date, amount: Double, fromChart: Bool, diaryNote: DiaryNoteItem?) -> Single<DiaryNoteItem> { .never() }
    func sendCombinedDiaryNote(diaryNote: DiaryNoteWeHaveNoticedItem) -> Single<DiaryNoteItem> { .never() }
    func deleteDiaryNote(noteID: String) -> Single<()> { .never() }
    func sendSpyroResults(results: [String: Any]) -> Single<()> { .never() }

    func refreshUser() -> Single<User> { .never() }
    func sendUserInfoParameters(userParameterRequests: [UserInfoParameterRequest]) -> Single<User> { .never() }
    func getUserData() -> Single<UserData> { .never() }
    func getUserSettings() -> Single<UserSettings> { .never() }
    func sendUserSettings(seconds: Int?, notificationTime: Int?) -> Single<()> { .never() }

    func getSurvey(surveyId: String) -> Single<SurveyGroup> { .never() }
    func sendSurveyTaskResult(surveyTaskId: String, results: [SurveyResult]) -> Single<()> { .never() }
    func getStudyInfoSection() -> Single<StudyInfoSection> { .never() }
    func sendDeviceData(deviceData: DeviceData) -> Single<()> { .never() }
    func getInfoMessages() -> Single<[MessageInfo]> { .never() }
}
