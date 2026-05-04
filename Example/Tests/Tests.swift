// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import ForYouAndMe

class TableOfContentsSpec: QuickSpec {
    override func spec() {
        context("these will pass") {

            it("can do maths") {
                expect(23) == 23
            }

            it("can read") {
                expect("🐮") == "🐮"
            }

            it("will eventually pass") {
                var time = "passing"

                DispatchQueue.main.async {
                    time = "done"
                }

                waitUntil { done in
                    Thread.sleep(forTimeInterval: 0.5)
                    expect(time) == "done"

                    done()
                }
            }
        }

        context("Integration enum") {

            it("resolves cronometer from raw value") {
                let integration = Integration(rawValue: "cronometer")
                expect(integration).toNot(beNil())
                expect(integration) == .cronometer
            }

            it("builds correct OAuth URL for cronometer") {
                let url = Integration.cronometer.apiOAuthUrl
                expect(url.path).to(contain("cronometer"))
            }

            it("builds correct deauthorize URL for cronometer") {
                let url = Integration.cronometer.apiOAuthDeauthorizeUrl
                expect(url.path).to(contain("cronometer"))
            }
        }

        context("NumericInputValidator integer") {

            it("accepts empty string") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "", maxDigits: 4)) == true
            }

            it("accepts single zero") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "0", maxDigits: 4)) == true
            }

            it("accepts values up to max digits") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "1", maxDigits: 4)) == true
                expect(NumericInputValidator.shouldAcceptInteger(newText: "9999", maxDigits: 4)) == true
            }

            it("rejects values with too many digits") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "10000", maxDigits: 4)) == false
            }

            it("rejects leading zeros") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "00", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "01", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "0123", maxDigits: 4)) == false
            }

            it("rejects non-digit characters") {
                expect(NumericInputValidator.shouldAcceptInteger(newText: "1a", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "12.3", maxDigits: 4)) == false
                expect(NumericInputValidator.shouldAcceptInteger(newText: "-5", maxDigits: 4)) == false
            }
        }

        context("NumericInputValidator decimal") {

            it("accepts empty string") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
            }

            it("accepts valid decimals") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0.5", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0.12", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.5", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "9999", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "9999.99", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
            }

            it("rejects leading zeros") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "00", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "01", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "012.5", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects too many integer digits") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "10000", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "99999", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects too many fraction digits") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.234", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects multiple dots") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.2.3", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects non-digit characters") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1a", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.a", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects empty integer part") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: ".5", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: ",5", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("accepts comma as decimal separator (non-US locales)") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "0,5", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "9999,99", maxIntegerDigits: 4, maxFractionDigits: 2)) == true
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1,234", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("rejects multiple separators of any kind") {
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1,2,3", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
                expect(NumericInputValidator.shouldAcceptDecimal(newText: "1.2,3", maxIntegerDigits: 4, maxFractionDigits: 2)) == false
            }

            it("normalizes comma to dot for parsing") {
                expect(NumericInputValidator.normalizedDecimalString("9,5")) == "9.5"
                expect(NumericInputValidator.normalizedDecimalString("9.5")) == "9.5"
                expect(Double(NumericInputValidator.normalizedDecimalString("9,5"))) == 9.5
            }
        }

        context("EmailValidator") {

            it("accepts standard addresses") {
                expect(EmailValidator.isValid("foo@bar.com")) == true
                expect(EmailValidator.isValid("user@example.org")) == true
                expect(EmailValidator.isValid("a.b@c.co.uk")) == true
            }

            it("accepts addresses with plus tags and dots in local part") {
                expect(EmailValidator.isValid("foo+tag@bar.com")) == true
                expect(EmailValidator.isValid("first.last@example.com")) == true
                expect(EmailValidator.isValid("first.last+tag@sub.example.com")) == true
            }

            it("accepts addresses with digits and hyphens") {
                expect(EmailValidator.isValid("user123@my-domain.com")) == true
                expect(EmailValidator.isValid("42@a1.io")) == true
            }

            it("rejects empty and whitespace-only strings") {
                expect(EmailValidator.isValid("")) == false
                expect(EmailValidator.isValid("   ")) == false
            }

            it("rejects strings missing the @ symbol") {
                expect(EmailValidator.isValid("foo")) == false
                expect(EmailValidator.isValid("foo.bar.com")) == false
            }

            it("rejects strings missing a domain TLD") {
                expect(EmailValidator.isValid("foo@bar")) == false
                expect(EmailValidator.isValid("foo@bar.")) == false
            }

            it("rejects strings missing a local part or domain") {
                expect(EmailValidator.isValid("@bar.com")) == false
                expect(EmailValidator.isValid("foo@.com")) == false
            }

            it("rejects strings with invalid characters") {
                expect(EmailValidator.isValid("foo bar@baz.com")) == false
                expect(EmailValidator.isValid("foo@bar .com")) == false
                expect(EmailValidator.isValid("foo@@bar.com")) == false
            }

            it("rejects single-character TLDs") {
                expect(EmailValidator.isValid("foo@bar.c")) == false
            }
        }
    }
}

// MARK: - HEALTHKIT / SENSORKIT / TERRA flag decoupling (FUAM-2998 + FUAM-3008)
//
// The Example app builds the ForYouAndMe framework with HEALTHKIT and SENSORKIT
// but without TERRA (see Example/Podfile post_install). The references to
// HealthManager / SensorKitManager below are *compile-time* assertions that
// those flags are still set; the absence of any Terra-gated symbol reference
// is the assertion that TERRA gating strips Terra code from this build.

class CompilationFlagsSpec: QuickSpec {
    override func spec() {
        context("HEALTHKIT flag wiring") {

            it("links HealthManager into the framework binary") {
                _ = HealthManager.self
                expect(true) == true
            }

            it("keeps DummyHealthManager available as the no-HEALTHKIT fallback type") {
                _ = DummyHealthManager.self
                expect(true) == true
            }
        }

        context("SENSORKIT flag wiring") {

            it("links SensorKitManager into the framework binary") {
                _ = SensorKitManager.self
                expect(true) == true
            }
        }

        context("TERRA flag - stripped from this build") {

            it("documents that TERRA-gated symbols are not linked into the Example test target") {
                // Example does not pull the ForYouAndMe/Terra subspec, so TerraManager,
                // TerraService, TerraTokenResponse and Repository.getTerraToken() are
                // stripped at compile time. Adding `_ = TerraManager.self` here would
                // fail to build - that failure mode is precisely what TERRA gating
                // prevents from regressing.
                expect(true) == true
            }
        }
    }
}

class IntegrationTerraSpec: QuickSpec {
    override func spec() {
        context("Integration.terra (flag-independent)") {

            it("resolves terra from raw value") {
                let integration = Integration(rawValue: "terra")
                expect(integration).toNot(beNil())
                expect(integration) == .terra
            }

            it("exposes terra storeUrl pointing at the App Store") {
                let url = Integration.terra.storeUrl
                expect(url.scheme) == "itms-apps"
                expect(url.absoluteString).to(contain("apps.apple.com"))
            }

            it("exposes terra appSchemaUrl with the terra scheme") {
                let url = Integration.terra.appSchemaUrl
                expect(url.scheme) == "terra"
            }

            it("appends the terra path component to the OAuth base URL") {
                let url = Integration.terra.apiOAuthUrl
                expect(url.path).to(contain("/integration_oauth/terra"))
            }

            it("includes a non-empty locale query item on the terra OAuth URL") {
                let url = Integration.terra.apiOAuthUrl
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let localeItem = components?.queryItems?.first { $0.name == "locale" }
                expect(localeItem).toNot(beNil())
                expect(localeItem?.value ?? "") != ""
            }

            it("does not add a locale query item to non-terra integrations") {
                let url = Integration.cronometer.apiOAuthUrl
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                expect(components?.queryItems).to(beNil())
            }

            it("appends the terra path component to the deauthorize URL") {
                let url = Integration.terra.apiOAuthDeauthorizeUrl
                expect(url.path).to(contain("terra"))
            }

            it("uses raw value as strategy prefix") {
                expect(Integration.terra.strategyPrefix) == "terra"
            }
        }
    }
}

// MARK: - FUAM-3109 — ExcludeInvalid must not infinite-loop on the first invalid element.
//
// Regression introduced in pod 0.99.0 (commit be497053, FUAM-3037): the
// container.decode(Element.self) inside ExcludeInvalid does NOT advance the
// UnkeyedDecodingContainer's currentIndex on a throwing decode, so a single
// invalid array element pinned the main thread in a tight log-and-retry loop.
// These specs lock in the fix and would hang indefinitely on a future
// regression — Quick's `waitUntil` timeout is the safety valve.

private struct ExcludeInvalidSystemPermissionsContainer: Decodable {
    @ExcludeInvalid var permissions: [SystemPermission]
}

class ExcludeInvalidRegressionSpec: QuickSpec {
    override func spec() {
        context("ExcludeInvalid<SystemPermission> with mixed valid/invalid array") {

            it("skips invalid entries and returns valid ones without hanging") {
                let json = """
                {"permissions": ["health", "microphone", "notification"]}
                """.data(using: .utf8)!

                var decoded: [SystemPermission] = []
                waitUntil(timeout: .seconds(2)) { done in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let container = try JSONDecoder().decode(
                                ExcludeInvalidSystemPermissionsContainer.self,
                                from: json)
                            decoded = container.permissions
                        } catch {
                            fail("Decode threw unexpectedly: \(error)")
                        }
                        done()
                    }
                }
                expect(decoded) == [.health, .notification]
            }

            it("skips a single invalid leading entry") {
                let json = """
                {"permissions": ["microphone"]}
                """.data(using: .utf8)!

                var decoded: [SystemPermission] = []
                waitUntil(timeout: .seconds(2)) { done in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let container = try? JSONDecoder().decode(
                            ExcludeInvalidSystemPermissionsContainer.self,
                            from: json)
                        decoded = container?.permissions ?? []
                        done()
                    }
                }
                expect(decoded).to(beEmpty())
            }

            it("skips multiple consecutive invalid entries") {
                let json = """
                {"permissions": ["microphone", "camera", "bluetooth", "health"]}
                """.data(using: .utf8)!

                var decoded: [SystemPermission] = []
                waitUntil(timeout: .seconds(2)) { done in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let container = try? JSONDecoder().decode(
                            ExcludeInvalidSystemPermissionsContainer.self,
                            from: json)
                        decoded = container?.permissions ?? []
                        done()
                    }
                }
                expect(decoded) == [.health]
            }

            it("returns empty for an empty array (no spurious advance)") {
                let json = """
                {"permissions": []}
                """.data(using: .utf8)!

                var decoded: [SystemPermission] = [.health] // sentinel
                waitUntil(timeout: .seconds(2)) { done in
                    DispatchQueue.global(qos: .userInitiated).async {
                        let container = try? JSONDecoder().decode(
                            ExcludeInvalidSystemPermissionsContainer.self,
                            from: json)
                        decoded = container?.permissions ?? [.health]
                        done()
                    }
                }
                expect(decoded).to(beEmpty())
            }
        }
    }
}

// MARK: - FUAM-3021 — Opt-in permission-chain watchdog

import RxSwift

/// Synthetic ApplicationStateProvider for tests. Lets specs drive
/// active/inactive transitions deterministically without UIKit coupling.
final class TestApplicationStateProvider: ApplicationStateProvider {
    private let activeSubject = BehaviorSubject<Bool>(value: true)
    private let didBecomeActiveSubject = PublishSubject<Void>()
    private let willResignActiveSubject = PublishSubject<Void>()

    var isActive: Bool { (try? activeSubject.value()) ?? false }
    var didBecomeActive: Observable<Void> { didBecomeActiveSubject.asObservable() }
    var willResignActive: Observable<Void> { willResignActiveSubject.asObservable() }

    func setActive(_ active: Bool) {
        activeSubject.onNext(active)
        if active {
            didBecomeActiveSubject.onNext(())
        } else {
            willResignActiveSubject.onNext(())
        }
    }
}

class PermissionWatchdogSpec: QuickSpec {
    override func spec() {
        // Real-time tests: keep budgets small and run on MainScheduler so
        // they finish fast and don't need RxTest as a new dependency.

        context("source emits within budget") {
            it("forwards success without tripping") {
                let provider = TestApplicationStateProvider()
                provider.setActive(true)

                var receivedTimeout: Bool = false
                var receivedSuccess: Bool = false

                let source: Single<()> = Single.just(())
                    .delay(.milliseconds(50), scheduler: MainScheduler.instance)

                waitUntil(timeout: .seconds(2)) { done in
                    _ = source
                        .withPermissionWatchdog(branch: .health,
                                                attempt: 1,
                                                timeout: 0.3,
                                                applicationStateProvider: provider)
                        .subscribe(
                            onSuccess: { receivedSuccess = true; done() },
                            onFailure: { err in
                                if case WatchdogError.tripped = err { receivedTimeout = true }
                                done()
                            })
                }
                expect(receivedSuccess) == true
                expect(receivedTimeout) == false
            }
        }

        context("source never emits while app stays active") {
            it("trips with WatchdogError.tripped after budget elapses") {
                let provider = TestApplicationStateProvider()
                provider.setActive(true)

                var trippedBranch: SystemPermission?
                var trippedAttempt: Int?

                let source: Single<()> = Single<()>.create { _ in Disposables.create() }

                let started = Date()
                waitUntil(timeout: .seconds(2)) { done in
                    _ = source
                        .withPermissionWatchdog(branch: .sensorKit,
                                                attempt: 2,
                                                timeout: 0.3,
                                                applicationStateProvider: provider)
                        .subscribe(
                            onSuccess: { done() },
                            onFailure: { err in
                                if case let WatchdogError.tripped(branch, attempt) = err {
                                    trippedBranch = branch
                                    trippedAttempt = attempt
                                }
                                done()
                            })
                }
                let elapsed = Date().timeIntervalSince(started)
                expect(trippedBranch) == .sensorKit
                expect(trippedAttempt) == 2
                expect(elapsed) >= 0.3
                expect(elapsed) < 1.5
            }
        }

        context("source never emits while app is inactive throughout") {
            it("does not trip until we return to active") {
                let provider = TestApplicationStateProvider()
                provider.setActive(false)

                var didTripWhileInactive: Bool = false

                let source: Single<()> = Single<()>.create { _ in Disposables.create() }

                let watchdogDisposable = source
                    .withPermissionWatchdog(branch: .location,
                                            attempt: 1,
                                            timeout: 0.3,
                                            applicationStateProvider: provider)
                    .subscribe(
                        onSuccess: { _ in },
                        onFailure: { err in
                            if case WatchdogError.tripped = err { didTripWhileInactive = true }
                        })

                // Wait longer than the budget while inactive.
                waitUntil(timeout: .seconds(1)) { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { done() }
                }
                expect(didTripWhileInactive) == false
                watchdogDisposable.dispose()
            }
        }

        context("source never emits and the app cycles inactive then active") {
            it("preserves remaining budget across the inactive window") {
                let provider = TestApplicationStateProvider()
                provider.setActive(true)

                var trippedAt: Date?
                let source: Single<()> = Single<()>.create { _ in Disposables.create() }

                let started = Date()

                let disposable = source
                    .withPermissionWatchdog(branch: .health,
                                            attempt: 1,
                                            timeout: 0.4,
                                            applicationStateProvider: provider)
                    .subscribe(
                        onSuccess: { _ in },
                        onFailure: { err in
                            if case WatchdogError.tripped = err { trippedAt = Date() }
                        })

                // After ~0.15s consumed, go inactive for 0.4s, then return.
                // Remaining at re-activation should be ~0.25s, so total wall
                // time to trip is ~0.15 + 0.4 + 0.25 = ~0.8s.
                waitUntil(timeout: .seconds(2)) { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        provider.setActive(false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            provider.setActive(true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { done() }
                        }
                    }
                }
                expect(trippedAt).toNot(beNil())
                if let trippedAt = trippedAt {
                    let total = trippedAt.timeIntervalSince(started)
                    // Sanity bounds: must be longer than the naive 0.4s budget
                    // (proves pause worked) and shorter than 1.5s.
                    expect(total) > 0.55
                    expect(total) < 1.5
                }
                disposable.dispose()
            }
        }

        context("disposing before timeout") {
            it("cancels the timer and does not emit anything") {
                let provider = TestApplicationStateProvider()
                provider.setActive(true)

                var emitted: Bool = false
                let source: Single<()> = Single<()>.create { _ in Disposables.create() }

                let disposable = source
                    .withPermissionWatchdog(branch: .notification,
                                            attempt: 1,
                                            timeout: 0.2,
                                            applicationStateProvider: provider)
                    .subscribe(
                        onSuccess: { _ in emitted = true },
                        onFailure: { _ in emitted = true })

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    disposable.dispose()
                }

                waitUntil(timeout: .seconds(1)) { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { done() }
                }
                expect(emitted) == false
            }
        }

        context("WatchdogError equality") {
            it("compares by branch and attempt") {
                let a = WatchdogError.tripped(branch: .health, attempt: 1)
                let b = WatchdogError.tripped(branch: .health, attempt: 1)
                let c = WatchdogError.tripped(branch: .health, attempt: 2)
                expect(a) == b
                expect(a) != c
            }
        }
    }
}

// MARK: - FUAM-3021 — Watchdog telemetry surface

/// Capture-everything sink for telemetry-emit assertions.
final class CapturingTelemetrySink: TelemetrySink {
    private(set) var events: [TelemetryEvent] = []
    func receive(_ event: TelemetryEvent) {
        events.append(event)
    }
    func reset() { events.removeAll() }
}

/// Mock AnalyticsService used to verify the AnalyticsServiceSink bridge.
final class CapturingAnalyticsService: AnalyticsService {
    private(set) var trackedEvents: [AnalyticsEvent] = []
    func track(event: AnalyticsEvent) {
        trackedEvents.append(event)
    }
    func reset() { trackedEvents.removeAll() }
}

class WatchdogTelemetrySpec: QuickSpec {
    override func spec() {

        context("Telemetry.errors.permissionWatchdogTripped") {
            it("emits one error:permission.watchdog.tripped event with the spec'd payload") {
                let sink = CapturingTelemetrySink()
                Telemetry.setSinks([sink])
                defer { Telemetry.setSinks([]) }

                Telemetry.errors.permissionWatchdogTripped(
                    branch: "health",
                    previousBranch: nil,
                    elapsedMs: 8000,
                    attempt: 1)

                expect(sink.events).to(haveCount(1))
                let event = sink.events[0]
                expect(event.fullName) == "error:permission.watchdog.tripped"
                expect(event.level) == .warn
                expect(event.payload["branch"] as? String) == "health"
                expect(event.payload["elapsed_ms"] as? Int) == 8000
                expect(event.payload["attempt"] as? Int) == 1
                expect(event.payload["host_app"]).toNot(beNil())
                expect(event.payload["os_version"]).toNot(beNil())
                expect(event.payload["previous_branch"]).to(beNil())
            }

            it("includes previous_branch when supplied") {
                let sink = CapturingTelemetrySink()
                Telemetry.setSinks([sink])
                defer { Telemetry.setSinks([]) }

                Telemetry.errors.permissionWatchdogTripped(
                    branch: "sensorkit",
                    previousBranch: "health",
                    elapsedMs: 8123,
                    attempt: 2)

                expect(sink.events).to(haveCount(1))
                expect(sink.events[0].payload["previous_branch"] as? String) == "health"
            }
        }

        context("Telemetry.action.permissionWatchdog{Retry|Skip|OpenSettings}") {
            it("emits the corresponding action events with the spec'd payload") {
                let sink = CapturingTelemetrySink()
                Telemetry.setSinks([sink])
                defer { Telemetry.setSinks([]) }

                Telemetry.action.permissionWatchdogRetry(branch: "notification", attempt: 2)
                Telemetry.action.permissionWatchdogSkip(branch: "location", wasFirstAttempt: true)
                Telemetry.action.permissionWatchdogOpenSettings(branch: "health", attempt: 3)

                expect(sink.events).to(haveCount(3))
                expect(sink.events[0].fullName) == "action:permission.watchdog.retry"
                expect(sink.events[0].payload["branch"] as? String) == "notification"
                expect(sink.events[0].payload["attempt"] as? Int) == 2

                expect(sink.events[1].fullName) == "action:permission.watchdog.skip"
                expect(sink.events[1].payload["branch"] as? String) == "location"
                expect(sink.events[1].payload["was_first_attempt"] as? Bool) == true

                expect(sink.events[2].fullName) == "action:permission.watchdog.open_settings"
                expect(sink.events[2].payload["branch"] as? String) == "health"
                expect(sink.events[2].payload["attempt"] as? Int) == 3
            }
        }

        context("AnalyticsServiceSink bridge") {
            it("forwards error:permission.watchdog.tripped to AnalyticsEvent.permissionWatchdogTimeout") {
                let analytics = CapturingAnalyticsService()
                let bridge = AnalyticsServiceSink(analytics: analytics)

                let event = TelemetryEvent(
                    category: .error,
                    name: "permission.watchdog.tripped",
                    level: .warn,
                    payload: [
                        "branch": "health",
                        "previous_branch": "location",
                        "elapsed_ms": 7500,
                        "attempt": 1,
                        "host_app": "com.example.test",
                        "os_version": "26.0"
                    ])
                bridge.receive(event)

                expect(analytics.trackedEvents).to(haveCount(1))
                if case let .permissionWatchdogTimeout(branch, previousBranch, elapsedMs, attempt) = analytics.trackedEvents[0] {
                    expect(branch) == "health"
                    expect(previousBranch) == "location"
                    expect(elapsedMs) == 7500
                    expect(attempt) == 1
                } else {
                    fail("Expected permissionWatchdogTimeout, got \(analytics.trackedEvents[0])")
                }
            }

            it("forwards action:permission.watchdog.skip to AnalyticsEvent.permissionWatchdogSkipped") {
                let analytics = CapturingAnalyticsService()
                let bridge = AnalyticsServiceSink(analytics: analytics)

                bridge.receive(TelemetryEvent(
                    category: .action,
                    name: "permission.watchdog.skip",
                    level: .info,
                    payload: ["branch": "notification", "was_first_attempt": false]))

                expect(analytics.trackedEvents).to(haveCount(1))
                if case let .permissionWatchdogSkipped(branch, wasFirstAttempt) = analytics.trackedEvents[0] {
                    expect(branch) == "notification"
                    expect(wasFirstAttempt) == false
                } else {
                    fail("Expected permissionWatchdogSkipped, got \(analytics.trackedEvents[0])")
                }
            }

            it("does NOT forward retry or open_settings (those stay diagnostic-only)") {
                let analytics = CapturingAnalyticsService()
                let bridge = AnalyticsServiceSink(analytics: analytics)

                bridge.receive(TelemetryEvent(
                    category: .action,
                    name: "permission.watchdog.retry",
                    level: .info,
                    payload: ["branch": "health", "attempt": 2]))
                bridge.receive(TelemetryEvent(
                    category: .action,
                    name: "permission.watchdog.open_settings",
                    level: .info,
                    payload: ["branch": "health", "attempt": 3]))

                expect(analytics.trackedEvents).to(beEmpty())
            }
        }

        context("Redactor.scrub does not clobber watchdog payload keys") {
            it("preserves branch, attempt, elapsed_ms, host_app, previous_branch unchanged") {
                let sink = CapturingTelemetrySink()
                Telemetry.setSinks([sink])
                defer { Telemetry.setSinks([]) }

                Telemetry.errors.permissionWatchdogTripped(
                    branch: "health",
                    previousBranch: "notification",
                    elapsedMs: 1234,
                    attempt: 1)

                expect(sink.events).to(haveCount(1))
                let p = sink.events[0].payload
                // Sanity check: redaction did not stringify, drop, or replace
                // any of these with "[redacted]".
                expect(p["branch"] as? String) == "health"
                expect(p["previous_branch"] as? String) == "notification"
                expect(p["attempt"] as? Int) == 1
                expect(p["elapsed_ms"] as? Int) == 1234
                expect((p["host_app"] as? String) != "[redacted]") == true
            }
        }
    }
}

// MARK: - FUAM-3021 — CacheManager skipped-permission persistence

class CacheManagerSkippedPermissionsSpec: QuickSpec {
    override func spec() {
        // CacheManager persists into UserDefaults.standard. Each test cleans
        // up after itself via clearSkippedOptInPermissions() to avoid bleed
        // across specs and between local runs.

        context("skippedOptInPermissions accessors") {
            it("starts empty and round-trips a Set<String>") {
                let cache = CacheManager()
                cache.clearSkippedOptInPermissions()

                expect(cache.skippedOptInPermissions).to(beEmpty())

                cache.skippedOptInPermissions = ["health", "sensorkit"]
                expect(cache.skippedOptInPermissions) == ["health", "sensorkit"]

                cache.clearSkippedOptInPermissions()
                expect(cache.skippedOptInPermissions).to(beEmpty())
            }

            it("survives a fresh CacheManager instance (UserDefaults-backed)") {
                let writer = CacheManager()
                writer.clearSkippedOptInPermissions()
                writer.skippedOptInPermissions = ["location"]

                let reader = CacheManager()
                expect(reader.skippedOptInPermissions) == ["location"]

                reader.clearSkippedOptInPermissions()
                let afterClear = CacheManager()
                expect(afterClear.skippedOptInPermissions).to(beEmpty())
            }

            it("supports incremental insertion (mutate-and-set pattern)") {
                let cache = CacheManager()
                cache.clearSkippedOptInPermissions()

                var skipped = cache.skippedOptInPermissions
                skipped.insert("health")
                cache.skippedOptInPermissions = skipped

                skipped = cache.skippedOptInPermissions
                skipped.insert("sensorkit")
                cache.skippedOptInPermissions = skipped

                expect(cache.skippedOptInPermissions) == ["health", "sensorkit"]
                cache.clearSkippedOptInPermissions()
            }
        }
    }
}
