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

    // FUAM-3021 v3 (FUAM-3118). Watchdog state — perpetual silent-retry model.
    /// Tick count per branch. Each tick of the watchdog ticker (every
    /// `Constants.OnboardingPermissionWatchdog.tickInterval` seconds while a
    /// branch's `Single<()>` is pending) increments this counter. Reset to 0
    /// when the user taps Retry on the watchdog popup. Cleared from the dict
    /// when the chain advances past the branch (success or skip).
    private var watchdogTickCounts: [SystemPermission: Int] = [:]
    private var currentChainDisposable: Disposable?
    /// Defensive guard #1: prevents `runOptInChain` re-entry from a UI
    /// double-tap or rebinding while a chain is already in flight. The
    /// internal Skip handler bypasses this via `forceRestart: true`.
    /// Belt-and-suspenders to the disabled-Submit-button defense in
    /// `OptInPermissionViewController.setProcessing(_:)` (FUAM-3116).
    private var isChainInFlight: Bool = false
    /// Defensive guard #3: ensure `completionCallback` fires at most once
    /// per coordinator lifetime. Mirrors the once-only semantics of the
    /// PagedSectionCoordinator's `performCustomPrimaryButtonNavigation`.
    private var didFireCompletion: Bool = false
    /// FUAM-3116. Weak ref to the currently-presented opt-in permission VC
    /// so the coordinator can drive its in-progress overlay during the chain.
    private weak var currentPermissionVC: OptInPermissionViewController?
    /// FUAM-3021 v3 (D5). Weak ref to the currently-presented watchdog
    /// popup so we can dismiss it if the source emits success while it is
    /// on screen (avoids orphaned modals when the user grants HK after
    /// our popup already appeared in front of a hidden HK sheet).
    private weak var currentWatchdogAlert: UIAlertController?

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
    }

    deinit {
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
        self.watchdogTickCounts.removeAll()

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
        guard self.didFireCompletion == false else { return }
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
        guard granted || false == optInPermission.isMandatory else {
            let message = optInPermission.mandatoryText ?? StringsProvider.string(forKey: .onboardingOptInMandatoryDefault)
            self.navigationController.showAlert(withTitle: StringsProvider.string(forKey: .onboardingOptInMandatoryTitle),
                                                message: message,
                                                dismissButtonText: StringsProvider.string(forKey: .onboardingOptInMandatoryClose))
            return
        }

        self.runOptInChain(for: optInPermission, granted: granted, startingAt: nil, forceRestart: false)
    }

    // MARK: - FUAM-3021 v3 — perpetual silent-retry chain runner

    /// Builds and subscribes to the per-branch permission chain for the
    /// given opt-in permission, optionally starting at a specific branch
    /// (used by Skip resumption). Disposes any in-flight chain subscription
    /// first so we never have two chains racing.
    ///
    /// In v3, the watchdog never disposes the chain — only Skip or success
    /// does. On each tick of a pending branch, the coordinator may decide
    /// to surface a Retry/Skip popup, but the underlying source `Single<()>`
    /// stays alive throughout.
    ///
    /// Defensive guards baked in:
    /// - `isChainInFlight` prevents re-entry from a UI double-tap. Internal
    ///   Skip handler bypasses via `forceRestart: true`.
    private func runOptInChain(for optInPermission: OptInPermission,
                               granted: Bool,
                               startingAt resumeBranch: SystemPermission?,
                               forceRestart: Bool) {
        // Defensive guard #1: refuse re-entry from external callers while a
        // chain is already in flight. Internal callers (Skip) pass
        // `forceRestart: true` because they're explicitly replacing the
        // current chain.
        if self.isChainInFlight && !forceRestart { return }

        // If a previous chain is still subscribed, dispose it before
        // subscribing a new one so we never have two chains racing.
        if let existing = self.currentChainDisposable {
            existing.dispose()
            self.currentChainDisposable = nil
        }

        // FUAM-3116. Show the in-progress overlay on the current opt-in card
        // immediately so the user gets visual feedback that the chain has
        // started — Submit is disabled, the card is dimmed, and a spinner +
        // localized "Setting up permissions…" label is centered. The overlay
        // stays visible throughout the perpetual silent-retry cycle.
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

        var chain: Single<()> = Single.just(())

        for branch in branches {
            chain = chain.flatMap { [weak self] _ -> Single<()> in
                guard let self = self else { return .just(()) }
                return self.wrappedBranchRequest(branch,
                                                 granted: granted,
                                                 optInPermission: optInPermission)
            }.flatMap { interStepDelay }
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
                // D5: dismiss any presented watchdog popup before advancing
                // — the source emitted success while the popup was on
                // screen (e.g., HK granted while user was reading the
                // popup), and we don't want orphaned modals.
                self.dismissWatchdogAlertIfPresented()
                // Clear processing BEFORE advancing — the old card is
                // about to be popped or covered, but we don't want a
                // stale spinner if the user navigates back.
                self.currentPermissionVC?.setProcessing(false)
                self.advanceAfterPermissionSet(optInPermission)
            }, onFailure: { [weak self] error in
                // Non-watchdog errors only — the v3 watchdog never errors
                // the chain. Permission-denied was already swallowed in
                // `wrappedBranchRequest`'s `.catchAndReturn(())`.
                guard let self = self else { return }
                self.dismissWatchdogAlertIfPresented()
                self.currentPermissionVC?.setProcessing(false)
                self.navigator.handleError(error: error, presenter: self.navigationController)
            })
    }

    /// Wraps the per-branch request with the v3 perpetual-tick watchdog
    /// and the permission-denied-is-OK swallow. Branches the user
    /// explicitly skipped short-circuit to a no-op.
    private func wrappedBranchRequest(_ branch: SystemPermission,
                                      granted: Bool,
                                      optInPermission: OptInPermission) -> Single<()> {
        if self.cacheService.skippedOptInPermissions.contains(branch.rawValue) {
            return Single.just(())
        }

        let source = self.buildBranchRequest(branch, granted: granted)
        // Reset the tick count for this branch at the start of its wait —
        // we only count ticks while we're actively waiting for this
        // specific source to emit.
        self.watchdogTickCounts[branch] = 0

        return source
            .withPermissionWatchdogTicks(
                tickInterval: Constants.OnboardingPermissionWatchdog.tickInterval,
                tickHandler: { [weak self] tick in
                    guard let self = self else { return }
                    self.handleWatchdogTick(branch: branch,
                                            tick: tick,
                                            optInPermission: optInPermission,
                                            granted: granted)
                }
            )
            .do(onSuccess: { [weak self] _ in
                // Branch resolved — clear its tick counter.
                self?.watchdogTickCounts[branch] = nil
            })
            .catchAndReturn(())  // permission denied = OK, advance chain
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

    private func advanceAfterPermissionSet(_ optInPermission: OptInPermission) {
        guard let permissionIndex = self.sectionData.optInPermissions
                .firstIndex(where: { $0.id == optInPermission.id }) else {
            assertionFailure("Missing Permission with given ID")
            return
        }

        // Branch succeeded all the way through to the backend submission;
        // safe to clear tick counts for branches the user just walked through.
        for branch in optInPermission.systemPermissions {
            self.watchdogTickCounts[branch] = nil
        }

        let nextPermissionIndex = permissionIndex + 1
        if nextPermissionIndex < self.sectionData.optInPermissions.count {
            self.showOptInPermission(self.sectionData.optInPermissions[nextPermissionIndex])
        } else {
            self.showSuccess()
        }
    }

    // MARK: - Watchdog tick + popup handlers (v3)

    /// Called by the watchdog operator on every tick (every
    /// `tickInterval` seconds) while a branch's `Single<()>` is pending.
    /// Increments the per-branch counter and, on every Nth tick (where
    /// N == `silentTicksPerCycle`), tries to surface the Retry/Skip popup.
    /// First (`silentTicksPerCycle - 1`) ticks are silent — no UI, no
    /// telemetry.
    private func handleWatchdogTick(branch: SystemPermission,
                                    tick: Int,
                                    optInPermission: OptInPermission,
                                    granted: Bool) {
        self.watchdogTickCounts[branch] = tick
        let silentTicksPerCycle = Constants.OnboardingPermissionWatchdog.silentTicksPerCycle
        guard tick > 0, tick % silentTicksPerCycle == 0 else { return }
        let attempt = tick / silentTicksPerCycle
        self.presentWatchdogPopupIfPossible(branch: branch,
                                            attempt: attempt,
                                            optInPermission: optInPermission,
                                            granted: granted)
    }

    /// Attempts to present the watchdog popup. Bails (silently — no
    /// telemetry, no state change) if anything modally covers our card or
    /// if the app is not foreground-active. The next tick (3 s later)
    /// re-checks; the popup will land naturally as soon as the modal
    /// dismisses or the app becomes active again.
    private func presentWatchdogPopupIfPossible(branch: SystemPermission,
                                                attempt: Int,
                                                optInPermission: OptInPermission,
                                                granted: Bool) {
        // D2 + D6 muting:
        // - presentedViewController != nil → in-process modal (HK/SK sheet,
        //   our own popup from a previous tick, any other modal) is on top.
        // - applicationState != .active → OS-process alert (Notification,
        //   Location) is on top.
        // Either case: do not present. Wait for next tick.
        if self.navigationController.presentedViewController != nil { return }
        if UIApplication.shared.applicationState != .active { return }

        // Telemetry fires only when the popup is actually presented to the
        // user (D4). Silent ticks and muted ticks are unremarkable.
        let elapsedMs = Int(Constants.OnboardingPermissionWatchdog.tickInterval
                            * Double(attempt * Constants.OnboardingPermissionWatchdog.silentTicksPerCycle)
                            * 1000)
        Telemetry.Errors.permissionWatchdogTripped(
            branch: branch.rawValue,
            previousBranch: nil,
            elapsedMs: elapsedMs,
            attempt: attempt)

        let title = StringsProvider.string(forKey: .onboardingOptInWatchdogTitle)
        let message = StringsProvider.string(forKey: .onboardingOptInWatchdogMessage)

        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.view.tintColor = ColorPalette.color(withType: .primary)

        let retryAction = UIAlertAction(
            title: StringsProvider.string(forKey: .onboardingOptInWatchdogRetry),
            style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.currentWatchdogAlert = nil
                self.retryBranch(branch: branch, attempt: attempt)
            }

        let skipAction = UIAlertAction(
            title: StringsProvider.string(forKey: .onboardingOptInWatchdogSkip),
            style: .cancel) { [weak self] _ in
                guard let self = self else { return }
                self.currentWatchdogAlert = nil
                self.skipBranch(branch: branch,
                                optInPermission: optInPermission,
                                granted: granted,
                                wasFirstAttempt: attempt == 1)
            }

        alert.addAction(retryAction)
        alert.addAction(skipAction)

        self.currentWatchdogAlert = alert
        self.navigationController.present(alert, animated: true, completion: nil)
    }

    /// "Retry" in the popup: from the user's POV, "try again". Internally,
    /// nothing is retried — the source `Single<()>` was never disposed,
    /// it's still waiting. We just dismiss the popup, reset the tick
    /// counter so another `silentTicksPerCycle` ticks can pass before
    /// the next popup, and emit telemetry.
    private func retryBranch(branch: SystemPermission, attempt: Int) {
        Telemetry.Action.permissionWatchdogRetry(branch: branch.rawValue, attempt: attempt)
        self.watchdogTickCounts[branch] = 0
    }

    private func skipBranch(branch: SystemPermission,
                            optInPermission: OptInPermission,
                            granted: Bool,
                            wasFirstAttempt: Bool) {
        Telemetry.Action.permissionWatchdogSkip(branch: branch.rawValue, wasFirstAttempt: wasFirstAttempt)
        var skipped = self.cacheService.skippedOptInPermissions
        skipped.insert(branch.rawValue)
        self.cacheService.skippedOptInPermissions = skipped
        self.watchdogTickCounts[branch] = nil

        let allBranches = optInPermission.systemPermissions
        if let index = allBranches.firstIndex(of: branch), index + 1 < allBranches.count {
            // Resume the chain at the branch after the skipped one. The
            // current chain is disposed and a fresh one is constructed via
            // runOptInChain(forceRestart: true).
            self.runOptInChain(for: optInPermission,
                               granted: granted,
                               startingAt: allBranches[index + 1],
                               forceRestart: true)
        } else {
            // The skipped branch was the last in this opt-in permission's
            // chain. Submit to the backend and advance to the next opt-in.
            // Keep the processing overlay visible across the brief backend
            // POST so the user has continuous feedback.
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

    /// D5 — if a watchdog popup is currently presented and the source
    /// emits success in the meantime, dismiss the popup before advancing
    /// the chain. Avoids orphaned modals when the user (e.g.) finally
    /// grants HK with our popup on top of the HK sheet.
    private func dismissWatchdogAlertIfPresented() {
        guard let alert = self.currentWatchdogAlert else { return }
        self.currentWatchdogAlert = nil
        alert.dismiss(animated: true, completion: nil)
    }
}
