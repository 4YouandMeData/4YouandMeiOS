//
//  GoogleHealthOAuthCoordinator.swift
//  ForYouAndMe
//
//  Created for FUAM-3418 — Google Health OAuth fix.
//
//  Google's secure-browser policy rejects WKWebView-driven OAuth with
//  `Error 403: disallowed_useragent`: the embedded WKWebView UA is missing
//  the `Safari/604.1` token Google looks for. SFSafariViewController runs the
//  real Safari engine (with the full Safari UA) and is therefore accepted.
//
//  SFSafariViewController doesn't expose a per-redirect callback the way
//  WKWebView's WKNavigationDelegate does, so we cannot observe the BE's final
//  302 to `/users/google_health/success`. Completion is detected when the
//  user dismisses the browser via `safariViewControllerDidFinish` and we then
//  refresh the user and inspect `currentUser.identities` for `google_health`.
//
//  Scoped to `.googleHealth` only — other providers stay on the cookie-based
//  WKWebView path since Google's secure-browser policy doesn't apply to them.
//

import Foundation
import SafariServices
import RxSwift

/// Result of the Google Health OAuth flow as observed by the SDK after the
/// user dismisses the SFSafariViewController.
enum GoogleHealthOAuthOutcome {
    /// `currentUser.identities` now contains `google_health` after the
    /// post-dismissal refresh.
    case success
    /// The user dismissed the browser without completing the consent flow,
    /// or the BE didn't record the linkage (e.g. they cancelled on Google's
    /// side, or the refresh failed). We don't distinguish "cancelled" from
    /// "errored" here — the device list will reflect reality on its own next
    /// refresh.
    case dismissedWithoutSuccess
}

/// Drives the Google Health OAuth flow. Lives as long as the
/// SFSafariViewController is on screen — `AppNavigator` retains it via
/// `currentGoogleHealthOAuthCoordinator` and releases it after the completion
/// callback fires.
final class GoogleHealthOAuthCoordinator: NSObject {

    typealias Completion = (GoogleHealthOAuthOutcome) -> Void

    private let repository: Repository
    private let completion: Completion
    private let disposeBag = DisposeBag()

    /// Set to true while we are in the middle of (or have already fired) the
    /// completion callback. Guards against double-fire if the system delivers
    /// `safariViewControllerDidFinish` twice (e.g. dismissal + view
    /// controller deallocation under some iOS versions).
    private var completionFired: Bool = false

    init(repository: Repository, completion: @escaping Completion) {
        self.repository = repository
        self.completion = completion
        super.init()
    }

    /// Builds the SFSafariViewController for the given URL. The caller is
    /// responsible for presenting it.
    func makeSafariViewController(url: URL) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = ColorPalette.color(withType: .primaryText)
        safari.preferredBarTintColor = ColorPalette.color(withType: .secondary)
        safari.delegate = self
        return safari
    }

    // MARK: - Private

    private func fireCompletion(_ outcome: GoogleHealthOAuthOutcome) {
        guard !self.completionFired else { return }
        self.completionFired = true
        self.completion(outcome)
    }
}

extension GoogleHealthOAuthCoordinator: SFSafariViewControllerDelegate {

    /// Fires when the user taps Safari's chrome "Done" button or otherwise
    /// dismisses the modal. SFSafariViewController has already begun its own
    /// dismissal animation by the time we receive this — we just need to
    /// refresh the user and report the outcome.
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        self.repository.refreshUser()
            .subscribe(onSuccess: { [weak self] user in
                guard let self = self else { return }
                let linked = user.identities.contains(Integration.googleHealth.rawValue)
                self.fireCompletion(linked ? .success : .dismissedWithoutSuccess)
            }, onFailure: { [weak self] _ in
                // Refresh failed for some reason (network, auth). The device
                // list's own viewWillAppear refresh will retry — we just
                // can't tell here whether the linkage took.
                self?.fireCompletion(.dismissedWithoutSuccess)
            })
            .disposed(by: self.disposeBag)
    }
}
