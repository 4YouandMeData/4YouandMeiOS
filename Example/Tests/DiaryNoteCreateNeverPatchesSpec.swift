//
//  DiaryNoteCreateNeverPatchesSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-4255 — An emoji picked before a note exists must travel IN the create
//  POST itself (`feedback_tags_attributes: [{ tag: ... }]`), never a follow-up
//  PATCH: a PATCH targets a server record id, and a brand-new note (including
//  a chart-started placeholder, whose id is a client-side UUID) has none yet.
//  This replaces the former POST-then-PATCH `sendDiaryNoteTextWithFeedback`
//  chain, which 404'd when the PATCH target was never written to the backend.
//
//  Drives a real RepositoryImpl through a scripted FakeApiGateway and asserts
//  both the note handed to the POST and that no PATCH is ever issued for it.
//  Covers the repository/network layer; DiaryNoteEmojiCreateFlowSpec covers the
//  view-controller-level decision of whether an emoji is held or PATCHed at all.
//

import Quick
import Nimble
import RxSwift
@testable import ForYouAndMe

class DiaryNoteCreateNeverPatchesSpec: QuickSpec {
    override class func spec() {
        describe("RepositoryImpl.sendDiaryNoteText never issues a follow-up PATCH") {

            var api: FakeApiGateway!
            var repository: RepositoryImpl!
            var disposeBag: DisposeBag!

            beforeEach {
                api = FakeApiGateway()
                repository = RepositoryImpl(api: api,
                                            storage: FakeRepositoryStorage(),
                                            notificationService: FakeNotificationService(),
                                            analyticsService: FakeAnalyticsService(),
                                            showDefaultUserInfo: false,
                                            appleWatchAlternativeIntegrations: [])
                disposeBag = DisposeBag()
            }

            afterEach {
                disposeBag = nil
            }

            func makeNote(id: String = "77", body: String? = "Hello") -> DiaryNoteItem {
                return DiaryNoteItem(id: id,
                                     type: "diary_note",
                                     diaryNoteId: Date(),
                                     diaryNoteType: .text,
                                     title: nil,
                                     body: body,
                                     interval: nil)
            }

            func emoji(tag: String = "🥵") -> EmojiItem {
                return EmojiItem(id: "", type: "feedback_tag", tag: tag, label: nil)
            }

            func run(diaryNote: DiaryNoteItem, fromChart: Bool) -> (result: DiaryNoteItem?, error: Error?) {
                var result: DiaryNoteItem?
                var error: Error?
                waitUntil(timeout: .seconds(5)) { done in
                    repository.sendDiaryNoteText(diaryNote: diaryNote, fromChart: fromChart)
                        .subscribe(onSuccess: { note in
                            result = note
                            done()
                        }, onFailure: { err in
                            error = err
                            done()
                        })
                        .disposed(by: disposeBag)
                }
                return (result, error)
            }

            context("when no emoji is held (feedbackTagToSet is nil)") {
                it("POSTs once, never PATCHes, and never attaches feedbackTagsToSet to the note") {
                    api.postDiaryNoteResult = makeNote()

                    var note = makeNote(id: "local")
                    note.feedbackTagToSet = nil
                    let outcome = run(diaryNote: note, fromChart: false)

                    expect(outcome.error).to(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(0))
                    expect(api.lastPostedNote?.feedbackTagToSet).to(beNil())
                }
            }

            context("when an emoji is held before the note exists (Diary-tab/FAB new note)") {
                it("POSTs once with the emoji on the note, and never PATCHes") {
                    api.postDiaryNoteResult = makeNote(id: "555")

                    var note = makeNote(id: "local")
                    note.feedbackTagToSet = emoji(tag: "🥵")
                    let outcome = run(diaryNote: note, fromChart: false)

                    expect(outcome.error).to(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(0))
                    // The emoji rides along ON the posted note, not in a follow-up call.
                    expect(api.lastPostedNote?.feedbackTagToSet?.tag).to(equal("🥵"))
                    expect(api.lastPostedFromChart).to(equal(false))
                }
            }

            context("when an emoji is held on a chart-started placeholder note") {
                it("POSTs once (fromChart) with the emoji on the note, and never PATCHes") {
                    api.postDiaryNoteResult = makeNote(id: "556")

                    // A chart-started note carries a client-side placeholder id, never
                    // written to the backend, until this very POST.
                    var note = DiaryNoteItem(date: Date(),
                                             body: "",
                                             interval: "day",
                                             diaryNoteable: DiaryNoteable(id: "12", type: "chart"))
                    note.feedbackTagToSet = emoji(tag: "😀")
                    let outcome = run(diaryNote: note, fromChart: true)

                    expect(outcome.error).to(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(0))
                    expect(api.lastPostedNote?.feedbackTagToSet?.tag).to(equal("😀"))
                    expect(api.lastPostedFromChart).to(equal(true))
                }
            }

            context("when the POST itself fails") {
                it("errors and never PATCHes") {
                    api.postDiaryNoteResult = nil // POST scripted to fail

                    var note = makeNote(id: "local")
                    note.feedbackTagToSet = emoji()
                    let outcome = run(diaryNote: note, fromChart: false)

                    expect(outcome.result).to(beNil())
                    expect(outcome.error).toNot(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(0))
                }
            }
        }
    }
}

// MARK: - Minimal RepositoryImpl collaborators

private final class FakeRepositoryStorage: RepositoryStorage {
    var globalConfig: GlobalConfig?
    var user: User?
    var infoMessages: [MessageInfo]?
    var feedbackList: [String: [EmojiItem]] = [:]
}

private final class FakeNotificationService: NotificationService {
    func getRegistrationToken() -> Single<String?> { .just(nil) }
}

private final class FakeAnalyticsService: AnalyticsService {
    func track(event: AnalyticsEvent) {}
}
