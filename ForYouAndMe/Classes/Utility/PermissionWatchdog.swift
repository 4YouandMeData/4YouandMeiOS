//
//  PermissionWatchdog.swift
//  ForYouAndMe
//
//  Created for FUAM-3021 — defensive watchdog for OptInSectionCoordinator's
//  permission chain (Approach B from FUAM-3020).
//

import Foundation
import RxSwift
import UIKit

// MARK: - Error type

enum WatchdogError: Error, Equatable {
    case tripped(branch: SystemPermission, attempt: Int)
}

// MARK: - Application-state abstraction (testable)

protocol ApplicationStateProvider {
    var isActive: Bool { get }
    var didBecomeActive: Observable<Void> { get }
    var willResignActive: Observable<Void> { get }
}

final class UIApplicationStateProvider: ApplicationStateProvider {
    static let shared = UIApplicationStateProvider()
    private init() {}

    var isActive: Bool {
        if Thread.isMainThread {
            return UIApplication.shared.applicationState == .active
        } else {
            var result = false
            DispatchQueue.main.sync {
                result = UIApplication.shared.applicationState == .active
            }
            return result
        }
    }

    var didBecomeActive: Observable<Void> {
        return NotificationCenter.default.rx
            .notification(UIApplication.didBecomeActiveNotification)
            .map { _ in () }
    }

    var willResignActive: Observable<Void> {
        return NotificationCenter.default.rx
            .notification(UIApplication.willResignActiveNotification)
            .map { _ in () }
    }
}

// MARK: - Operator

extension PrimitiveSequence where Trait == SingleTrait, Element == () {

    /// Wraps a permission `Single<()>` with an inactive-aware watchdog timer.
    ///
    /// The timer only consumes budget while
    /// `UIApplication.applicationState == .active`, so time the user spends
    /// reading the iOS system permission alert (which puts the app in
    /// `.inactive`) does not count against the configured timeout. This is
    /// what makes the watchdog distinguish a real "stuck" branch (FUAM-3014
    /// race classic) from a slow-reading user.
    ///
    /// Disposing the returned `Single<()>` cancels the timer and the source
    /// subscription. Note that disposing does NOT cancel the underlying iOS
    /// permission request — once iOS has presented the system alert, the OS
    /// owns it and our app cannot dismiss it programmatically.
    func withPermissionWatchdog(branch: SystemPermission,
                                attempt: Int,
                                timeout: TimeInterval,
                                applicationStateProvider: ApplicationStateProvider
                                    = UIApplicationStateProvider.shared,
                                scheduler: SchedulerType
                                    = MainScheduler.instance) -> Single<()> {
        return Single<()>.create { observer in
            let watchdog = ActivePauseWatchdog(
                budget: timeout,
                branch: branch,
                attempt: attempt,
                applicationStateProvider: applicationStateProvider,
                scheduler: scheduler,
                onTimeout: { error in observer(.failure(error)) }
            )

            let sourceDisposable = self.subscribe(
                onSuccess: { _ in
                    watchdog.cancel()
                    observer(.success(()))
                },
                onFailure: { err in
                    watchdog.cancel()
                    observer(.failure(err))
                }
            )

            watchdog.start()

            return Disposables.create {
                watchdog.cancel()
                sourceDisposable.dispose()
            }
        }
    }
}

// MARK: - Watchdog implementation

/// Internal watchdog timer. Pauses when the app goes inactive and resumes
/// (with the remaining budget) when it returns to active. Fires exactly once.
final class ActivePauseWatchdog {

    private let budget: TimeInterval
    private let branch: SystemPermission
    private let attempt: Int
    private let applicationStateProvider: ApplicationStateProvider
    private let scheduler: SchedulerType
    private let onTimeout: (WatchdogError) -> Void

    private let lock = NSLock()
    private var remaining: TimeInterval
    private var timerDisposable: Disposable?
    private var lifecycleBag: DisposeBag?
    private var lastResumeAt: Date?
    private var hasFired: Bool = false
    private var hasStarted: Bool = false

    /// Wall-clock elapsed time consumed by the watchdog — only ticks while
    /// the app is `.active`. Used by callers (the coordinator) for telemetry
    /// payloads so they don't have to track Date themselves.
    var elapsedActiveTime: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return budget - remaining
    }

    init(budget: TimeInterval,
         branch: SystemPermission,
         attempt: Int,
         applicationStateProvider: ApplicationStateProvider,
         scheduler: SchedulerType,
         onTimeout: @escaping (WatchdogError) -> Void) {
        self.budget = budget
        self.remaining = budget
        self.branch = branch
        self.attempt = attempt
        self.applicationStateProvider = applicationStateProvider
        self.scheduler = scheduler
        self.onTimeout = onTimeout
    }

    func start() {
        let bag = DisposeBag()
        applicationStateProvider.willResignActive
            .subscribe(onNext: { [weak self] in self?.pause() })
            .disposed(by: bag)
        applicationStateProvider.didBecomeActive
            .subscribe(onNext: { [weak self] in self?.resume() })
            .disposed(by: bag)

        lock.lock()
        lifecycleBag = bag
        hasStarted = true
        lock.unlock()

        if applicationStateProvider.isActive {
            resume()
        }
    }

    func cancel() {
        lock.lock()
        hasFired = true
        timerDisposable?.dispose()
        timerDisposable = nil
        lifecycleBag = nil
        lock.unlock()
    }

    private func pause() {
        lock.lock()
        guard !hasFired else { lock.unlock(); return }
        timerDisposable?.dispose()
        timerDisposable = nil
        if let last = lastResumeAt {
            let elapsed = Date().timeIntervalSince(last)
            remaining = max(0, remaining - elapsed)
            lastResumeAt = nil
        }
        lock.unlock()
    }

    private func resume() {
        lock.lock()
        guard !hasFired else { lock.unlock(); return }
        guard timerDisposable == nil else { lock.unlock(); return }

        if remaining <= 0 {
            // Already exhausted while we were inactive — fire on resume.
            lock.unlock()
            fire()
            return
        }

        lastResumeAt = Date()
        let dueRemaining = remaining
        let timer = Observable<Int>
            .timer(.milliseconds(Int(dueRemaining * 1000)), scheduler: scheduler)
            .take(1)
            .subscribe(onNext: { [weak self] _ in self?.fire() })
        timerDisposable = timer
        lock.unlock()
    }

    private func fire() {
        lock.lock()
        if hasFired {
            lock.unlock()
            return
        }
        hasFired = true
        timerDisposable?.dispose()
        timerDisposable = nil
        lifecycleBag = nil
        lock.unlock()
        onTimeout(.tripped(branch: branch, attempt: attempt))
    }
}
