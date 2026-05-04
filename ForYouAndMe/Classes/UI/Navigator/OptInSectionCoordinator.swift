//
//  OptInSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/2020.
//

import Foundation
import RxSwift
import UIKit

class OptInSectionCoordinator {

    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false

    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = true

    public unowned var navigationController: UINavigationController

    private let repository: Repository
    private let navigator: AppNavigator
    // FUAM-3021. `var` because we mutate `skippedOptInPermissions` through
    // the protocol's setter; CacheService is not class-bound so a `let`
    // reference would be immutable through-the-protocol.
    private var cacheService: CacheService

    private let sectionData: OptInSection
    private let completionCallback: NavigationControllerCallback

    private let disposeBag = DisposeBag()

    private let healthService: HealthService
    private let deviceService: DeviceService
    #if SENSORKIT
    private let sensorKitService: SensorKitService?
    #endif

    var answers: [Question: PossibleAnswer] = [:]

    // FUAM-3021. Watchdog state.
    private var watchdogStrikes: [SystemPermission: Int] = [:]
    private var currentChainDisposable: Disposable?
    /// Defensive guard #1: prevents `runOptInChain` re-entry from a UI
    /// double-tap or rebinding while a chain is already in flight. The
    /// internal Retry/Skip handlers bypass this via `forceRestart: true`.
    /// Belt-and-suspenders to the disabled-Submit-button defense in
    /// `OptInPermissionViewController.setProcessing(_:)` (FUAM-3116).
    private var isChainInFlight: Bool = false
    /// Defensive guard #3: ensure `completionCallback` fires at most once
    /// per coordinator lifetime. Mirrors the once-only semantics of the
    /// PagedSectionCoordinator's `performCustomPrimaryButtonNavigation`.
    private var didFireCompletion: Bool = false
    /// FUAM-3116. Weak ref to the currently-presented opt-in permission VC
    /// so the coordinator can drive its in-progress overlay around the
    /// chain. Set in `showOptInPermission(_:)`; cleared automatically when
    /// the VC pops or is replaced.
    private weak var currentPermissionVC: OptInPermissionViewController?

    init(withSectionData sectionData: OptInSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.repository = Services.shared.repository
        self.navigator = Services.shared.navigator
        self.cacheService = Services.shared.storageServices
        self.healthService = Services.shared.healthService
        self.deviceService = Services.shared.deviceService
#if SENSORKIT
        self.sensorKitService = Services.shared.sensorKitService
#endif

        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        print("[FUAM-3021-trace] OptInSectionCoordinator.init optInPermissions.count=\(sectionData.optInPermissions.count)")
    }

    deinit {
        print("[FUAM-3021-trace] OptInSectionCoordinator.deinit")
        self.currentChainDisposable?.dispose()
    }

    // MARK: - Private Methods

    private func showSuccess() {
        // FUAM-3021. The opt-in section completed end-to-end; clear any
        // per-section watchdog skips so a future re-entry to the flow gets
        // a clean slate. NOTE: `didFireCompletion` is NOT set here — only
        // when the completion callback actually fires (either the no-success
        // -page branch below, or `performCustomPrimaryButtonNavigation` when
        // the user taps the success-page primary button).
        self.cacheService.clearSkippedOptInPermissions()
        self.watchdogStrikes.removeAll()

        if let successPage = self.sectionData.successPage {
            // Push the success page; the user's primary-button tap on that
            // page is what fires `completionCallback` — see
            // `performCustomPrimaryButtonNavigation` below.
            self.showResultPage(successPage)
        } else {
            self.fireCompletionOnce()
        }
    }

    /// Single chokepoint for invoking `completionCallback`. Idempotent.
    /// FUAM-3021: replaces an earlier (buggy) version that set
    /// `didFireCompletion = true` inside `showSuccess()` even when a success
    /// page was being pushed — that broke the success-page primary button
    /// path because by the time the user tapped it,
    /// `performCustomPrimaryButtonNavigation` saw `didFireCompletion == true`
    /// and returned without firing the callback (FUAM-3116 dead-end).
    private func fireCompletionOnce() {
        guard self.didFireCompletion == false else {
            print("[FUAM-3021-trace] completionCallback blocked: already fired")
            return
        }
        self.didFireCompletion = true
        self.completionCallback(self.navigationController)
    }

    private func showOptInPermission(_ optInPermission: OptInPermission) {
        let viewController = OptInPermissionViewController(withOptInPermission: optInPermission, coordinator: self)
        // FUAM-3116. Track the active VC so we can drive its processing
        // overlay during the permission chain.
        self.currentPermissionVC = viewController
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
}

extension OptInSectionCoordinator: PagedSectionCoordinator {

    var pages: [Page] { self.sectionData.pages }

    func getStartingPage() -> UIViewController {
        let infoPageData = InfoPageData(page: self.sectionData.welcomePage,
                                        addAbortOnboardingButton: false,
                                        addCloseButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .center,
                                        bottomViewStyle: .singleButton,
                                        customImageHeight: nil,
                                        defaultButtonFirstLabel: nil,
                                        defaultButtonSecondLabel: nil)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }

    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.fireCompletionOnce()
            return true
        }
        return false
    }

    func onUnhandledPrimaryButtonNavigation(page: Page) {
        if let firstOptInPermission = self.sectionData.optInPermissions.first {
            self.showOptInPermission(firstOptInPermission)
        } else {
            // No permissions to walk — section is effectively complete.
            self.fireCompletionOnce()
        }
    }
}

extension OptInSectionCoordinator: OptInPermissionCoordinator {
    func onOptInPermissionSet(optInPermission: OptInPermission, granted: Bool) {
        print("[FUAM-3021-trace] onOptInPermissionSet permission.id=\(optInPermission.id) granted=\(granted) systemPermissions=\(optInPermission.systemPermissions.map { $0.rawValue })")

        guard granted || false == optInPermission.isMandatory else {
            let message = optInPermission.mandatoryText ?? StringsProvider.string(forKey: .onboardingOptInMandatoryDefault)
            self.navigationController.showAlert(withTitle: StringsProvider.string(forKey: .onboardingOptInMandatoryTitle),
                                                message: message,
                                                dismissButtonText: StringsProvider.string(forKey: .onboardingOptInMandatoryClose))
            return
        }

        self.runOptInChain(for: optInPermission, granted: granted, startingAt: nil, forceRestart: false)
    }

    // MARK: - FUAM-3021 chain runner + watchdog handlers

    /// Builds and subscribes to the per-branch permission chain for the given
    /// opt-in permission, optionally starting at a specific branch (used by
    /// Retry / Skip resumption). Disposes any in-flight chain subscription
    /// first so we never have two chains racing.
    ///
    /// Defensive guards baked in:
    /// - `isChainInFlight` prevents re-entry from a UI double-tap. Internal
    ///   Retry/Skip handlers bypass via `forceRestart: true`.
    /// - Explicit `popProgressHUD()` if the prior chain didn't have a chance
    ///   to fire its onDispose before we re-subscribe.
    private func runOptInChain(for optInPermission: OptInPermission,
                               granted: Bool,
                               startingAt resumeBranch: SystemPermission?,
                               forceRestart: Bool) {
        // Defensive guard #1: refuse re-entry from external callers while a
        // chain is already in flight. Internal callers (Retry / Skip) pass
        // `forceRestart: true` because they're explicitly replacing the
        // current chain. With FUAM-3116's disabled-Submit defense at the UI
        // layer this is now belt-and-suspenders, but worth keeping.
        if self.isChainInFlight && !forceRestart {
            print("[FUAM-3021-trace] runOptInChain re-entry blocked (chain already in flight)")
            return
        }

        // Defensive guard #2: if a previous chain is still subscribed,
        // dispose it before subscribing a new one so we never have two
        // chains racing against each other.
        if let existing = self.currentChainDisposable {
            print("[FUAM-3021-trace] runOptInChain disposing previous chain before restart")
            existing.dispose()
            self.currentChainDisposable = nil
        }

        // FUAM-3116. Show the in-progress overlay on the current opt-in card
        // immediately so the user gets visual feedback that the chain has
        // started — Submit is disabled, the card is dimmed, and a spinner +
        // localized "Setting up permissions…" label is centered.
        self.currentPermissionVC?.setProcessing(true)

        // FUAM-3014: system permission prompts (HealthKit, SensorKit, …) dismiss
        // asynchronously. Their completion handlers can fire while the presenting
        // view controller is still animating out, so presenting the next prompt
        // immediately lands on a view that is no longer in the window hierarchy
        // — UIKit silently drops the presentation and the chain hangs. A small
        // delay between steps gives the previous prompt's dismissal animation
        // time to finish before the next step runs. FUAM-3015 will replace this
        // delay with event-driven dismissal signaling; the watchdog (FUAM-3021)
        // is the production safety net regardless of which mitigation is in
        // effect.
        let interStepDelay: Single<()> = Single.just(())
            .delay(.milliseconds(500), scheduler: MainScheduler.instance)

        let allBranches = optInPermission.systemPermissions
        let startIndex: Int = {
            guard let resumeBranch = resumeBranch,
                  let idx = allBranches.firstIndex(of: resumeBranch)
            else { return 0 }
            return idx
        }()
        let branches = Array(allBranches[startIndex...])

        var previousForLogging: SystemPermission? = startIndex > 0 ? allBranches[startIndex - 1] : nil
        var chain: Single<()> = Single.just(())

        for branch in branches {
            let attempt = (self.watchdogStrikes[branch] ?? 0) + 1
            let previousBranch = previousForLogging
            chain = chain.flatMap { [weak self] _ -> Single<()> in
                guard let self = self else { return .just(()) }
                return self.wrappedBranchRequest(branch,
                                                 granted: granted,
                                                 attempt: attempt,
                                                 previousBranch: previousBranch)
            }.flatMap { interStepDelay }
            previousForLogging = branch
        }

        self.isChainInFlight = true
        self.currentChainDisposable = chain
            .flatMap { [weak self] _ -> Single<()> in
                // FUAM-3116. SVProgressHUD is now scoped to the (brief)
                // backend submit only. The visible feedback during the
                // permission chain itself is the on-card processing
                // overlay (`OptInPermissionViewController.setProcessing`)
                // which stays visible the whole time, including across
                // OS prompts going inactive.
                guard let self = self else { return .just(()) }
                return self.repository
                    .sendOptInPermission(permission: optInPermission, granted: granted)
                    .addProgress()
            }
            .do(onDispose: { [weak self] in
                self?.isChainInFlight = false
            })
            .subscribe(onSuccess: { [weak self] () in
                guard let self = self else { return }
                // Clear processing BEFORE advancing — the old card is
                // about to be popped or covered, but we don't want a
                // stale spinner if the user navigates back.
                self.currentPermissionVC?.setProcessing(false)
                self.advanceAfterPermissionSet(optInPermission)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                if case let WatchdogError.tripped(branch, attempt) = error {
                    // Keep the processing overlay visible behind the
                    // watchdog alert. Retry/Skip resume the chain (overlay
                    // stays); a non-watchdog error path clears it.
                    self.handleWatchdogTimeout(branch: branch,
                                               attempt: attempt,
                                               optInPermission: optInPermission,
                                               granted: granted)
                } else {
                    self.currentPermissionVC?.setProcessing(false)
                    self.navigator.handleError(error: error, presenter: self.navigationController)
                }
            })
    }

    /// Wraps the per-branch request with the watchdog and the
    /// permission-denied-is-OK swallow. Branches the user explicitly skipped
    /// short-circuit to a no-op. Telemetry fires on watchdog trip.
    private func wrappedBranchRequest(_ branch: SystemPermission,
                                      granted: Bool,
                                      attempt: Int,
                                      previousBranch: SystemPermission?) -> Single<()> {
        if self.cacheService.skippedOptInPermissions.contains(branch.rawValue) {
            print("[FUAM-3021-trace] wrappedBranchRequest short-circuit for previously-skipped branch=\(branch.rawValue)")
            return Single.just(())
        }

        let source = self.buildBranchRequest(branch, granted: granted)
        let timeout = self.timeoutForBranch(branch)
        let started = Date()

        return source
            .withPermissionWatchdog(branch: branch, attempt: attempt, timeout: timeout)
            .do(onSuccess: { [weak self] _ in
                // Branch succeeded — reset its strike count.
                self?.watchdogStrikes[branch] = 0
            })
            .catch { error -> Single<()> in
                if case WatchdogError.tripped = error {
                    let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
                    Telemetry.errors.permissionWatchdogTripped(
                        branch: branch.rawValue,
                        previousBranch: previousBranch?.rawValue,
                        elapsedMs: elapsedMs,
                        attempt: attempt)
                    return Single.error(error)
                }
                // Permission-denied paths (and any other non-watchdog error)
                // continue to be swallowed so the chain advances. This
                // mirrors the original `.catchAndReturn(())` behaviour.
                return Single.just(())
            }
    }

    private func buildBranchRequest(_ branch: SystemPermission, granted: Bool) -> Single<()> {
        switch branch {
        case .health:
            return granted ? self.healthService.requestPermissions() : Single.just(())
        case .location:
            guard self.deviceService.locationServicesAvailable else {
                // location services not enabled for this study: do nothing.
                return Single.just(())
            }
            let permission: Permission = Constants.Misc.DefaultLocationPermission
            return granted ? permission.request() : Single.just(())
        case .notification:
            let permission: Permission = .notification
            return granted ? permission.request() : Single.just(())
        case .sensorKit:
            #if SENSORKIT
            guard let manager = Services.shared.sensorKitService as? SensorKitManager,
                  manager.serviceAvailable
            else { return .just(()) }

            if granted {
                return manager.requestPermissions()
                    .do(onSuccess: {
                        manager.ensureRecordingStarted()
                        manager.triggerSync(reason: "optin")
                    })
            } else {
                manager.refreshRecordingBasedOnClearance()
                return .just(())
            }
            #else
            return .just(())
            #endif
        }
    }

    private func timeoutForBranch(_ branch: SystemPermission) -> TimeInterval {
        switch branch {
        case .health:        return Constants.OnboardingPermissionTimeouts.healthKit
        case .sensorKit:     return Constants.OnboardingPermissionTimeouts.sensorKit
        case .location:      return Constants.OnboardingPermissionTimeouts.location
        case .notification:  return Constants.OnboardingPermissionTimeouts.notification
        }
    }

    private func advanceAfterPermissionSet(_ optInPermission: OptInPermission) {
        guard let permissionIndex = self.sectionData.optInPermissions
                .firstIndex(where: { $0.id == optInPermission.id }) else {
            assertionFailure("Missing Permission with given ID")
            return
        }

        // Branch succeeded all the way through to the backend submission;
        // safe to clear strikes for branches the user just walked through.
        for branch in optInPermission.systemPermissions {
            self.watchdogStrikes[branch] = 0
        }

        let nextPermissionIndex = permissionIndex + 1
        if nextPermissionIndex < self.sectionData.optInPermissions.count {
            self.showOptInPermission(self.sectionData.optInPermissions[nextPermissionIndex])
        } else {
            self.showSuccess()
        }
    }

    // MARK: - Watchdog alert handlers

    private func handleWatchdogTimeout(branch: SystemPermission,
                                       attempt: Int,
                                       optInPermission: OptInPermission,
                                       granted: Bool) {
        self.watchdogStrikes[branch, default: 0] += 1
        let strikes = self.watchdogStrikes[branch] ?? 1
        let escalated = strikes >= Constants.OnboardingPermissionTimeouts.strikeEscalationThreshold

        let title = StringsProvider.string(forKey: .onboardingOptInWatchdogTitle)
        let message = escalated
            ? StringsProvider.string(forKey: .onboardingOptInWatchdogUnavailableMessage)
            : StringsProvider.string(forKey: .onboardingOptInWatchdogMessage)
        let primaryActionTitle = escalated
            ? StringsProvider.string(forKey: .onboardingOptInWatchdogOpenSettings)
            : StringsProvider.string(forKey: .onboardingOptInWatchdogRetry)

        let primaryAction = UIAlertAction(title: primaryActionTitle, style: .default) { [weak self] _ in
            guard let self = self else { return }
            if escalated {
                // Per FUAM-3021 plan §C4: after 3 strikes, open Settings AND
                // implicitly skip the branch so the chain advances even if
                // the user does nothing in Settings.
                Telemetry.action.permissionWatchdogOpenSettings(branch: branch.rawValue, attempt: strikes)
                self.openAppSettings()
                self.skipBranch(branch: branch,
                                optInPermission: optInPermission,
                                granted: granted,
                                wasFirstAttempt: false)
            } else {
                self.retryBranch(branch: branch,
                                 optInPermission: optInPermission,
                                 granted: granted,
                                 attempt: strikes + 1)
            }
        }

        let skipAction = UIAlertAction(
            title: StringsProvider.string(forKey: .onboardingOptInWatchdogSkip),
            style: .cancel) { [weak self] _ in
            guard let self = self else { return }
            self.skipBranch(branch: branch,
                            optInPermission: optInPermission,
                            granted: granted,
                            wasFirstAttempt: strikes == 1)
        }

        self.navigationController.showAlert(withTitle: title,
                                            message: message,
                                            actions: [primaryAction, skipAction],
                                            tintColor: ColorPalette.color(withType: .primary))
    }

    private func retryBranch(branch: SystemPermission,
                             optInPermission: OptInPermission,
                             granted: Bool,
                             attempt: Int) {
        Telemetry.action.permissionWatchdogRetry(branch: branch.rawValue, attempt: attempt)
        self.runOptInChain(for: optInPermission, granted: granted, startingAt: branch, forceRestart: true)
    }

    private func skipBranch(branch: SystemPermission,
                            optInPermission: OptInPermission,
                            granted: Bool,
                            wasFirstAttempt: Bool) {
        Telemetry.action.permissionWatchdogSkip(branch: branch.rawValue, wasFirstAttempt: wasFirstAttempt)
        var skipped = self.cacheService.skippedOptInPermissions
        skipped.insert(branch.rawValue)
        self.cacheService.skippedOptInPermissions = skipped
        self.watchdogStrikes[branch] = 0

        let allBranches = optInPermission.systemPermissions
        if let index = allBranches.firstIndex(of: branch), index + 1 < allBranches.count {
            // Resume the chain at the branch after the skipped one.
            self.runOptInChain(for: optInPermission,
                               granted: granted,
                               startingAt: allBranches[index + 1],
                               forceRestart: true)
        } else {
            // The skipped branch was the last in this opt-in permission's
            // chain. Submit to the backend and advance to the next opt-in.
            // Keep the processing overlay visible across the brief backend
            // POST so the user has continuous feedback that the action is
            // being processed.
            self.currentChainDisposable?.dispose()
            self.isChainInFlight = true
            self.currentPermissionVC?.setProcessing(true)
            self.currentChainDisposable = self.repository
                .sendOptInPermission(permission: optInPermission, granted: granted)
                .addProgress()
                .do(onDispose: { [weak self] in self?.isChainInFlight = false })
                .subscribe(onSuccess: { [weak self] () in
                    self?.currentPermissionVC?.setProcessing(false)
                    self?.advanceAfterPermissionSet(optInPermission)
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.currentPermissionVC?.setProcessing(false)
                    self.navigator.handleError(error: error, presenter: self.navigationController)
                })
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
