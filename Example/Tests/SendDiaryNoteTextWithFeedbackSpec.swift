//
//  SendDiaryNoteTextWithFeedbackSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3495 — Locks down RepositoryImpl.sendDiaryNoteTextWithFeedback:
//  POST create → best-effort PATCH emoji (exactly one retry) → silent
//  `feedbackSaved` flag. The note must always survive; only the emoji attach
//  is allowed to silently fail. Drives a real RepositoryImpl through a
//  scripted FakeApiGateway and asserts both the returned tuple and the fake's
//  POST/PATCH call counts.
//

import Quick
import Nimble
import RxSwift
@testable import ForYouAndMe

class SendDiaryNoteTextWithFeedbackSpec: QuickSpec {
    override class func spec() {
        describe("RepositoryImpl.sendDiaryNoteTextWithFeedback") {

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

            func emoji(label: String? = nil, tag: String = "🥵") -> EmojiItem {
                return EmojiItem(id: "", type: "feedback_tag", tag: tag, label: label)
            }

            /// Runs the chain synchronously and returns the emitted tuple (or nil)
            /// plus any surfaced error.
            func run(diaryNote: DiaryNoteItem,
                     emoji: EmojiItem?) -> (result: (DiaryNoteItem, Bool)?, error: Error?) {
                let outcome = ChainOutcome()
                waitUntil(timeout: .seconds(5)) { done in
                    repository.sendDiaryNoteTextWithFeedback(diaryNote: diaryNote,
                                                             emoji: emoji,
                                                             fromChart: false)
                        .subscribe(onSuccess: { result in
                            outcome.result = result
                            done()
                        }, onFailure: { error in
                            outcome.error = error
                            done()
                        })
                        .disposed(by: disposeBag)
                }
                return (outcome.result, outcome.error)
            }

            context("when no emoji is picked (nil)") {
                it("POSTs once, never PATCHes, and reports feedbackSaved=true") {
                    let created = makeNote()
                    api.postDiaryNoteResult = created

                    let outcome = run(diaryNote: makeNote(), emoji: nil)

                    expect(outcome.error).to(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(0))
                    expect(outcome.result?.0.id).to(equal(created.id))
                    expect(outcome.result?.1).to(beTrue())
                }
            }

            context("when the 'none' sentinel emoji is picked") {
                it("never PATCHes and reports feedbackSaved=true") {
                    api.postDiaryNoteResult = makeNote()

                    let outcome = run(diaryNote: makeNote(),
                                      emoji: emoji(label: "none", tag: "❌"))

                    expect(outcome.error).to(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(0))
                    expect(outcome.result?.1).to(beTrue())
                }
            }

            context("when an emoji is picked and the PATCH succeeds first try") {
                it("POSTs once, PATCHes once, and chains the created id + emoji") {
                    let created = makeNote(id: "555")
                    api.postDiaryNoteResult = created
                    api.patchResults = [.success]

                    let outcome = run(diaryNote: makeNote(id: "local"),
                                      emoji: emoji(tag: "🥵"))

                    expect(outcome.error).to(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(1))
                    expect(outcome.result?.1).to(beTrue())
                    // The PATCH targets the server-created note, not the local draft.
                    expect(api.lastPatchedNote?.id).to(equal("555"))
                    // The picked emoji rides along in feedbackTags.
                    expect(api.lastPatchedNote?.feedbackTags?.last?.tag).to(equal("🥵"))
                }
            }

            context("when the emoji PATCH fails once then succeeds") {
                it("retries exactly once and reports feedbackSaved=true") {
                    api.postDiaryNoteResult = makeNote()
                    api.patchResults = [.failure(FakeApiError.scriptedFailure), .success]

                    let outcome = run(diaryNote: makeNote(), emoji: emoji())

                    expect(outcome.error).to(beNil())
                    expect(api.patchDiaryNoteCallCount).to(equal(2))
                    expect(outcome.result?.1).to(beTrue())
                }
            }

            context("when the emoji PATCH fails twice") {
                it("does NOT make a third attempt and silently reports feedbackSaved=false") {
                    let created = makeNote(id: "999")
                    api.postDiaryNoteResult = created
                    api.patchResults = [.failure(FakeApiError.scriptedFailure),
                                        .failure(FakeApiError.scriptedFailure),
                                        .success] // guard: proves no 3rd attempt is made

                    let outcome = run(diaryNote: makeNote(), emoji: emoji())

                    // No error surfaces; the note is still persisted.
                    expect(outcome.error).to(beNil())
                    expect(api.patchDiaryNoteCallCount).to(equal(2))
                    expect(outcome.result?.0.id).to(equal("999"))
                    expect(outcome.result?.1).to(beFalse())
                }
            }

            context("when the POST itself fails") {
                it("errors and never PATCHes") {
                    api.postDiaryNoteResult = nil // POST scripted to fail

                    let outcome = run(diaryNote: makeNote(), emoji: emoji())

                    expect(outcome.result).to(beNil())
                    expect(outcome.error).toNot(beNil())
                    expect(api.postDiaryNoteCallCount).to(equal(1))
                    expect(api.patchDiaryNoteCallCount).to(equal(0))
                }
            }
        }
    }
}

// MARK: - Helpers

/// Reference box so the async subscribe closures can write results without
/// capturing an `inout` parameter (which escaping closures forbid).
private final class ChainOutcome {
    var result: (DiaryNoteItem, Bool)?
    var error: Error?
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
