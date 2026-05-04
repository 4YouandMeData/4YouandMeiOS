//
//  PermissionWatchdog.swift
//  ForYouAndMe
//
//  Created for FUAM-3021 — defensive watchdog for OptInSectionCoordinator's
//  permission chain (Approach B from FUAM-3020).
//
//  v3 (FUAM-3118). Replaces v1/v2's one-shot pause-aware timeout with a
//  perpetual silent-retry tick stream. Rationale: iOS 17+'s HK/SK auth
//  sheets are in-process modals that do NOT trigger
//  UIApplication.willResignActiveNotification, so the v1/v2 pause logic
//  consumed budget during user-think time and tripped spuriously. The v3
//  model never "trips" — it just emits ticks; the coordinator decides
//  whether to surface UI on each tick.
//

import Foundation
import RxSwift

// MARK: - Operator

extension PrimitiveSequence where Trait == SingleTrait, Element == () {

    /// Wraps a permission `Single<()>` with a perpetual tick stream that
    /// fires `tickHandler` every `tickInterval` seconds while the source
    /// is still pending. The source emission (success or error) is
    /// forwarded to the subscriber unchanged; the tick stream is cancelled
    /// when the source emits or when the returned Single is disposed.
    ///
    /// `tickHandler` receives a 1-based tick index (1, 2, 3, …). The
    /// coordinator is expected to use `tick % silentTicksPerCycle == 0`
    /// to decide whether to attempt presenting the watchdog popup.
    ///
    /// The watchdog NEVER produces an error of its own. If the source
    /// hangs forever, the tick handler keeps firing forever; the user
    /// can always tap Skip on the popup to exit.
    func withPermissionWatchdogTicks(tickInterval: TimeInterval,
                                     tickHandler: @escaping (Int) -> Void,
                                     scheduler: SchedulerType
                                        = MainScheduler.instance) -> Single<()> {
        return Single<()>.create { observer in
            let tickDisposable = Observable<Int>
                .interval(.milliseconds(Int(tickInterval * 1000)),
                          scheduler: scheduler)
                // Observable<Int>.interval emits 0, 1, 2, …; the watchdog
                // contract uses 1-based tick numbers so the first tick is
                // the first 3-second mark, not the zeroth.
                .map { $0 + 1 }
                .subscribe(onNext: { tick in tickHandler(tick) })

            let sourceDisposable = self.subscribe(
                onSuccess: { _ in
                    tickDisposable.dispose()
                    observer(.success(()))
                },
                onFailure: { err in
                    tickDisposable.dispose()
                    observer(.failure(err))
                }
            )

            return Disposables.create {
                tickDisposable.dispose()
                sourceDisposable.dispose()
            }
        }
    }
}
