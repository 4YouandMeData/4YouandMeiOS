//
//  FakeApiGateway.swift
//  ForYouAndMe_Tests
//
//  FUAM-3495 / FUAM-4255 — Scriptable ApiGateway double used to drive
//  RepositoryImpl's `sendDiaryNoteText` (create) and `updateDiaryNoteText`
//  (PATCH) without hitting the network.
//
//  It inspects `ApiRequest.serviceRequest` and returns scripted responses for
//  the POST (`.sendDiaryNoteText`) and the PATCH (`.updateDiaryNoteText`):
//  - the POST resolves to a caller-supplied `DiaryNoteItem` (or errors), and
//    the posted note is captured so a test can assert what it carried (e.g.
//    a held emoji on `feedbackTagToSet`, FUAM-4255);
//  - the PATCH (`Single<()>`) replays a scripted sequence of results, so a
//    test can model "fails once then succeeds" or "fails twice".
//  Every POST and PATCH invocation is counted and the last PATCHed note is
//  captured so tests can assert PATCH-specific payloads.
//
//  Every other `ApiGateway` requirement is a `fatalError` stub: the chain
//  under test never touches them, and hitting one is a test-authoring bug we
//  want to surface loudly rather than silently succeed.
//

import Foundation
import RxSwift
@testable import ForYouAndMe

/// A single scripted outcome for a `Single<()>` request (the PATCH).
enum FakeVoidResult {
    case success
    case failure(Error)
}

/// Marker error the fake emits when a scripted PATCH failure is requested.
enum FakeApiError: Error {
    case scriptedFailure
}

final class FakeApiGateway: ApiGateway {

    // MARK: - Scripted responses

    /// Response for the POST `.sendDiaryNoteText`. When `nil` the POST errors
    /// with `FakeApiError.scriptedFailure`.
    var postDiaryNoteResult: DiaryNoteItem?

    /// Sequence of outcomes for the PATCH `.updateDiaryNoteText`, consumed one
    /// per invocation. If the script runs out, the fake defaults to `.success`.
    var patchResults: [FakeVoidResult] = [.success]

    // MARK: - Recorded invocations

    private(set) var postDiaryNoteCallCount = 0
    private(set) var patchDiaryNoteCallCount = 0
    private(set) var lastPostedNote: DiaryNoteItem?
    private(set) var lastPostedFromChart: Bool?
    private(set) var lastPatchedNote: DiaryNoteItem?

    // MARK: - Auth (unused by the chain under test)

    var accessToken: String?
    func isLoggedIn() -> Bool { false }
    func logOut() {}

    // MARK: - Routed sends

    // POST `.sendDiaryNoteText` resolves here (Single<DiaryNoteItem>).
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T> {
        switch request.serviceRequest {
        case .sendDiaryNoteText(let diaryItem, let fromChart):
            self.postDiaryNoteCallCount += 1
            self.lastPostedNote = diaryItem
            self.lastPostedFromChart = fromChart
            guard let note = self.postDiaryNoteResult as? T else {
                return .error(FakeApiError.scriptedFailure)
            }
            return .just(note)
        default:
            fatalError("FakeApiGateway: unexpected JSONAPIMappable send for \(request.serviceRequest)")
        }
    }

    // PATCH `.updateDiaryNoteText` resolves here (Single<()>).
    // Deferred so RxSwift's `retry(2)` re-runs the scripted sequence on each
    // re-subscription — otherwise `.just`/`.error` would be fixed at build time
    // and every retry would replay the very first outcome.
    func send<E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<()> {
        switch request.serviceRequest {
        case .updateDiaryNoteText(let diaryItem):
            return Single.deferred { [weak self] in
                guard let self = self else { return .just(()) }
                let index = self.patchDiaryNoteCallCount
                self.patchDiaryNoteCallCount += 1
                self.lastPatchedNote = diaryItem
                let result = index < self.patchResults.count ? self.patchResults[index] : .success
                switch result {
                case .success:
                    return .just(())
                case .failure(let error):
                    return .error(error)
                }
            }
        default:
            fatalError("FakeApiGateway: unexpected void send for \(request.serviceRequest)")
        }
    }

    // MARK: - Unused generic overloads (never exercised by the chain)

    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T> {
        fatalError("FakeApiGateway: unexpected Mappable send for \(request.serviceRequest)")
    }
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?> {
        fatalError("FakeApiGateway: unexpected optional Mappable send for \(request.serviceRequest)")
    }
    func send<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        fatalError("FakeApiGateway: unexpected Mappable array send for \(request.serviceRequest)")
    }
    func sendExcludeInvalid<T: Mappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        fatalError("FakeApiGateway: unexpected sendExcludeInvalid for \(request.serviceRequest)")
    }
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T?> {
        fatalError("FakeApiGateway: unexpected optional JSONAPIMappable send for \(request.serviceRequest)")
    }
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<[T]> {
        fatalError("FakeApiGateway: unexpected JSONAPIMappable array send for \(request.serviceRequest)")
    }
    func send<T: JSONAPIMappable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<ExcludeInvalid<T>> {
        fatalError("FakeApiGateway: unexpected ExcludeInvalid send for \(request.serviceRequest)")
    }
    func send<T: PlainDecodable, E: Mappable>(request: ApiRequest, errorType: E.Type) -> Single<T> {
        fatalError("FakeApiGateway: unexpected PlainDecodable send for \(request.serviceRequest)")
    }
}
