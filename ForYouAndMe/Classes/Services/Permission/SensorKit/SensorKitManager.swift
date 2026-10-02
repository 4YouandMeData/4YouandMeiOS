//
//  SensorKitManager.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 01/08/25.
//

import Foundation
import RxSwift
import SensorKit

/// Gate that allows/denies SensorKit collection+upload.
public protocol SensorSampleUploadManagerClearanceDelegate: AnyObject {
    /// Return `true` when the manager is allowed to run (e.g. consent active).
    var sensorManagerCanRun: Bool { get }

    /// The participant's **study join day** — start of day in the participant's timezone,
    /// derived from the backend's `days_in_study` (FUAM-3841, FUAM-3945). Feeds
    /// `BackfillLowerBound`, which bounds every backfill and gates every record's measurement
    /// timestamp. `nil` when it cannot be established (no user, or `days_in_study <= 0`),
    /// which means forward-only collection.
    var enrollmentDate: Date? { get }

    /// The participant's BACKEND-authoritative timezone (`user.time_zone`) — the calendar every
    /// window/batch boundary is computed in (FUAM-3945 AC2 revised): the same authority the
    /// adherence chart buckets rows with, and one that does not move when the participant
    /// travels. `nil` when no user record is loaded; the caller falls back to UTC (never to
    /// `TimeZone.current`).
    var participantTimeZone: TimeZone? { get }
}

// MARK: - Typealiases mirroring the Health side wiring

/// Payload type for SensorKit uploads
typealias SensorNetworkData = [String: Any]

/// Storage type expected by the upload manager (cursor + batch queue)
typealias SensorKitManagerStorage = SensorSampleUploadManagerStorage & SensorSampleUploaderStorage

/// Reachability abstraction used by the upload manager
typealias SensorKitManagerReachability = SensorSampleUploadManagerReachability

// MARK: - Delegates (network/clearance)

/// Network delegate at the "manager" level (high-level, app specific).
/// The upload manager will talk to it through a bridge (SensorNetworkBridge).
protocol SensorKitManagerNetworkDelegate: AnyObject {
    /// Uploads a payload to your backend. Use `source = "sensor_kit"` to tag it.
    func uploadSensorNetworkData(_ data: [String: Any], source: String) -> Single<()>
}

/// Clearance delegate gating collection/upload (consent, session, etc.)
protocol SensorKitManagerClearanceDelegate: SensorSampleUploadManagerClearanceDelegate {}

// MARK: - Manager

/// Primary entry-point for SensorKit in the app.
/// - Asks permissions for configured sensors
/// - Coordinates background/foreground upload via SensorSampleUploadManager
/// `NSObject` because the manager is the delegate of the RECORDING readers
/// (`SRSensorReaderDelegate` is `@objc`): a `startRecording()` that fails is otherwise
/// indistinguishable from one that succeeded (FUAM-3945 round 7, F3).
final class SensorKitManager: NSObject, SensorKitService {

    // MARK: State

    /// InitializableService-like flag (kept for parity with HealthManager)
    var isInitialized: Bool = false
    
    // Strong reference
    private var uploaderNetworkBridge: SensorNetworkBridge?

    /// Delegate that executes the actual network upload (bridge-adapted below).
    public weak var networkDelegate: SensorKitManagerNetworkDelegate? {
        didSet {
            guard let networkDelegate else { uploaderNetworkBridge = nil; return }
            let bridge = SensorNetworkBridge(adapter: networkDelegate)
            uploaderNetworkBridge = bridge
            sensorSampleUploadManager.setNetworkDelegate(bridge)
            if isInitialized { sensorSampleUploadManager.triggerSync(reason: "manager_delegate_set") }
        }
    }

    /// Clearance gate (consent, eligibility, etc.)
    public weak var clearanceDelegate: SensorKitManagerClearanceDelegate? {
        didSet {
            self.sensorSampleUploadManager.clearanceDelegate = clearanceDelegate
        }
    }

    // MARK: Configuration

    /// Sensors this manager will request and collect.
    private let readSensors: [SRSensor]
    
    /// Keep one reader per sensor so we can start/stop recording idempotently.
    private var recordingReaders: [SRSensor: SRSensorReader] = [:]

    /// Sensors whose `startRecording()` failure has already been reported this launch, so a
    /// permanently failing sensor does not emit an event on every `didBecomeActive`.
    /// Mutated from `SRSensorReaderDelegate` callbacks — one reader per sensor, each delivering
    /// on a framework-owned queue — so it is guarded, like `ServerClock`'s latch, by a single
    /// test-and-set critical section (`claimRecordingFailureReport`) rather than by a main-queue
    /// hop: a lock is smaller and does not delay the event.
    private var recordingFailureReported: Set<SRSensor> = []
    private let recordingFailureLock = NSLock()

    /// `true` for the first caller per sensor per launch. A locked read followed by a locked
    /// insert would still let two readers both see "not reported" and both emit.
    private func claimRecordingFailureReport(for sensor: SRSensor) -> Bool {
        self.recordingFailureLock.lock()
        defer { self.recordingFailureLock.unlock() }
        return self.recordingFailureReported.insert(sensor).inserted
    }

    // MARK: Dependencies

    private let analyticsService: AnalyticsService
    private let sensorSampleUploadManager: SensorSampleUploadManager
    /// D6 layer 3: sensors iOS empirically refused to prompt for. Self-correcting: cleared when
    /// the app version changes (a host that gains the entitlement in an update starts clean).
    private let refusalStore = SensorRefusalStore()

    private let disposeBag = DisposeBag()

    // MARK: Init

    /// Designated initializer.
    /// - Parameters:
    ///   - readSensors: The sensors to request and collect (e.g. [.accelerometer, ...])
    ///   - analyticsService: Analytics abstraction
    ///   - storage: Cursor + batch queue storage for the upload pipeline
    ///   - reachability: Network reachability
    ///   - mappers: Per-sensor mappers (sensor -> mapper) used by the upload pipeline
    init(withReadSensors readSensors: [SRSensor],
         analyticsService: AnalyticsService,
         storage: SensorKitManagerStorage,
         reachability: SensorKitManagerReachability,
         mappers: [SRSensor: SensorSampleMapper]) {

        precondition(!readSensors.isEmpty, "readSensors must not be empty")

        self.readSensors = readSensors
        self.analyticsService = analyticsService

        // Build the upload manager (fetch → batch → upload → cursor)
        self.sensorSampleUploadManager = SensorSampleUploadManager(
            withSensors: readSensors,
            storage: storage,
            reachability: reachability,
            analytics: analyticsService,
            mappers: mappers
        )

        super.init()
    }

    // MARK: - SensorKitService

    /// Availability gate (entitlements + Info.plist already configured on your build).
    var serviceAvailable: Bool { true }

    /// Canonical order in which we present the per-sensor system prompts. iOS displays
    /// them one at a time in the sequence we call `requestAuthorization(sensors:)`, so
    /// this array controls the user-visible order (FUAM-3370). Any sensor in
    /// `readSensors` that is not listed here is appended at the end, preserving its
    /// position relative to the others.
    private static let canonicalRequestOrder: [SRSensor] = [
        .messagesUsageReport,
        .deviceUsageReport,
        .keyboardMetrics,
        .phoneUsageReport,
        .pedometerData,
        .ambientLightSensor,
        .ambientPressure,
        .visits
    ]

    /// Returns the REQUESTABLE `.notDetermined` subset of `readSensors`, sorted by
    /// `canonicalRequestOrder` (sensors not in the canonical list keep their input order
    /// and go at the end). Sensors the refusal ledger marked as refused are excluded (D6
    /// layer 3): iOS has already shown it will never draw their prompt, so re-asking only
    /// re-triggers the fast auto-decline that used to be misread as "collection is off".
    private func orderedNotDeterminedSensors() -> [SRSensor] {
        let refused = self.refusalStore.refusedSensors()
        let undetermined = readSensors.filter {
            !refused.contains($0) && SRSensorReader(sensor: $0).authorizationStatus == .notDetermined
        }
        let undeterminedSet = Set(undetermined)
        let canonical = Self.canonicalRequestOrder.filter { undeterminedSet.contains($0) }
        let extras = undetermined.filter { !Self.canonicalRequestOrder.contains($0) }
        return canonical + extras
    }

    /// `true` when at least one effective, non-refused sensor could still be prompted for —
    /// the Permissions row's ACTION predicate (D7): run the request flow iff this holds,
    /// otherwise show the Manage/Settings alert. Distinct from the LABEL predicate
    /// (`hasAnyAuthorized`), deliberately: they answer two different questions.
    func hasRequestableUndeterminedSensors() -> Bool {
        return !self.orderedNotDeterminedSensors().isEmpty
    }

    /// Requests SensorKit authorization for all not-determined sensors in `readSensors`.
    /// Requests each sensor individually so one unapproved sensor does not crash the whole batch.
    /// Prompts appear in the order defined by `canonicalRequestOrder`.
    func requestPermissions() -> Single<()> {
        let toAsk = orderedNotDeterminedSensors()
        guard !toAsk.isEmpty else { return .just(()) }

        return Single.create { observer in
            if #available(iOS 17.4, *) {
                Task { @MainActor in
                    var firstError: Error?
                    for sensor in toAsk {
                        do {
                            try await SRSensorReader.requestAuthorization(sensors: [sensor])
                        } catch {
                            if firstError == nil { firstError = error }
                            #if DEBUG
                            print("SensorKitManager – requestAuthorization failed for \(sensor.rawValue): \(error)")
                            #endif
                        }
                    }
                    if let error = firstError {
                        self.analyticsService.track(event: .healthError(healthError: .permissionRequestError(underlyingError: error)))
                    }
                    observer(.success(()))
                }
            } else {
                self.requestAuthorizationSequentially(sensors: toAsk) { firstError in
                    DispatchQueue.main.async {
                        if let error = firstError {
                            self.analyticsService.track(event: .healthError(healthError: .permissionRequestError(underlyingError: error)))
                        }
                        observer(.success(()))
                    }
                }
            }
            return Disposables.create()
        }
    }

    /// Maximum elapsed time of a single `SRSensorReader.requestAuthorization` call for a
    /// `promptDeclined` error to be interpreted as the system-wide collection switch being
    /// OFF. When the master "Sensor & Usage Data Collection" switch is OFF the call
    /// auto-declines essentially instantly (a brief flash, well under this threshold),
    /// whereas a human reading and tapping Cancel on a real prompt always takes longer.
    /// Gating on this elapsed time distinguishes the two identical `promptDeclined` errors.
    /// (FUAM-3432)
    private static let collectionDisabledMaxElapsed: TimeInterval = 0.8

    /// `true` when this error is the instant auto-decline that a master switch being OFF — or a
    /// sensor the app is not entitled to — produces. Fast is necessary but not sufficient: see
    /// `setupOutcome(fastDeclineCount:askedCount:)`.
    static func isFastAutoDecline(error: Error, elapsed: TimeInterval) -> Bool {
        return self.isPromptDeclined(error) && elapsed < self.collectionDisabledMaxElapsed
    }

    /// Maximum elapsed time under which a `promptDeclined` can be treated as PROMPTLESS — no
    /// consent sheet was drawn, no human was involved (FUAM-3945 round 4, R2-2 residual). Sits
    /// well above `collectionDisabledMaxElapsed` on purpose: the confounder that broke the old
    /// unanimity-of-fast rule is the first call of a launch declining in ~0.9s on a cold
    /// SensorKit XPC start (round 8's own measurement) — still nowhere near a human reading the
    /// full-screen SensorKit consent sheet and tapping Cancel, which takes seconds. Between the
    /// two thresholds a decline is "promptless but not fast": machine-speed evidence, tolerated
    /// once per round (the cold start) by `setupOutcome`'s undeclared-host rule.
    private static let humanPromptMinElapsed: TimeInterval = 3.0

    /// `true` when this decline shows no evidence that a prompt was ever drawn: a
    /// `promptDeclined` returned faster than any human round-trip through the consent sheet.
    /// Every fast auto-decline is also promptless (`0.8 < 3.0`).
    static func isPromptlessDecline(error: Error, elapsed: TimeInterval) -> Bool {
        return self.isPromptDeclined(error) && elapsed < self.humanPromptMinElapsed
    }

    /// The verdict of a whole request sequence (FUAM-3945 round 8, corrected round 9 per D7/R3).
    ///
    /// A single fast `promptDeclined` used to be treated as proof that the system-wide "Sensor &
    /// Usage Data Collection" switch is OFF. It is not: a sensor the host has no entitlement for
    /// auto-declines exactly as fast, with the same error, while the switch is perfectly ON — which
    /// is how a participant who had granted everything still got the "collection is off" alert.
    ///
    /// Round 8's unanimity rule (`fastDeclineCount == askedCount`) over-corrected: one slow XPC
    /// cold-start on the first call of the launch (0.9s > the 0.8s threshold) made the sequence
    /// 7/8 fast and suppressed the alert while the master switch genuinely was off (review F4).
    /// The verdict is therefore decided AFTER the loop from the strongest evidence available:
    /// the switch is blamed only when nothing whatsoever ended `.authorized` AND enough of what
    /// was asked fast-declined. Anything authorized proves the switch is ON, whatever the
    /// timings said.
    ///
    /// The rule depends on whether the host DECLARED its entitlements (round 2, review F6):
    /// - with a `FYAMSensorKitEntitledSensors` declaration, unentitled sensors never reach the
    ///   request set, so fast declines are meaningful evidence — a majority blames the switch
    ///   (tolerating the one slow cold-start);
    /// - with NO declaration, unentitled sensors fast-decline while the switch is ON: a host
    ///   entitled to half its request set would otherwise false-alarm every time the user simply
    ///   denies the real prompts. Round 2 required unanimity of FAST declines there, which the
    ///   cold-start confounder defeated: with the switch genuinely OFF, the launch's first call
    ///   declines in ~0.9s > 0.8s, unanimity is unmet, and the participant never sees the
    ///   "re-enable Sensor & Usage Data Collection" alert (review R2-2, residual half). Round 4
    ///   decides from the OBSERVED evidence instead: the switch is blamed iff EVERY asked sensor
    ///   declined PROMPTLESSLY (no drawn-prompt evidence anywhere — a real human cancel takes
    ///   seconds and breaks this unanimity, so the entitled-half + user-denies host stays quiet)
    ///   AND all but at most one declined genuinely FAST (the exact shape of a switch-off round:
    ///   all instant, at most the one cold start). Residuals, accepted and narrower than before:
    ///   a switch-off round containing a non-`promptDeclined` failure or a >3s decline still
    ///   reports `.completed`, and an undeclared host entitled to NOTHING still false-alarms
    ///   with the switch ON (it always did, under every rule so far — indistinguishable without
    ///   a declaration).
    ///
    /// `promptlessDeclineCount` counts declines under `humanPromptMinElapsed` and is therefore
    /// always >= `fastDeclineCount`.
    static func setupOutcome(fastDeclineCount: Int,
                             promptlessDeclineCount: Int,
                             askedCount: Int,
                             anyAuthorizedAfterLoop: Bool,
                             hasEntitlementDeclaration: Bool) -> SensorKitSetupOutcome {
        guard !anyAuthorizedAfterLoop, askedCount > 0 else { return .completed }
        if hasEntitlementDeclaration {
            return fastDeclineCount >= max(1, askedCount / 2) ? .collectionDisabledSystemWide : .completed
        }
        return promptlessDeclineCount == askedCount && fastDeclineCount >= askedCount - 1
            ? .collectionDisabledSystemWide
            : .completed
    }

    /// The sensors this round proved iOS refuses to prompt for (D6 layer 3): asked,
    /// fast-declined with no prompt drawn, and still `.notDetermined`.
    ///
    /// Learning is gated on `anyAuthorizedAfterLoop` — PROOF the master switch is on — not on
    /// the round's verdict (round 3, review R2-2): on an undeclared host with the switch
    /// genuinely OFF, one slow cold-start decline breaks unanimity, the verdict comes back
    /// `.completed`, and a verdict-gated ledger would register EVERY sensor as a candidate;
    /// two such launches promoted them all to refused, locking them behind the Settings alert
    /// even after the participant re-enabled the switch. A round in which nothing authorized
    /// teaches the ledger nothing — which only forgoes learning in the one state where the
    /// verdict can be wrong. (Round 4 closed that verdict's false negative too — see
    /// `setupOutcome` — but the learning gate stays evidence-based on purpose: it must not
    /// depend on the verdict rule being right.) A SLOW decline (a real human cancel) is never
    /// recorded either: iOS will happily re-prompt it (R2 is exactly the ability to do so).
    static func refusals(fastDeclined: Set<SRSensor>,
                         stillNotDetermined: Set<SRSensor>,
                         anyAuthorizedAfterLoop: Bool) -> Set<SRSensor> {
        guard anyAuthorizedAfterLoop else { return [] }
        return fastDeclined.intersection(stillNotDetermined)
    }

    /// Requests SensorKit authorization for the not-determined sensors only, detecting
    /// the system-wide "Sensor & Usage Data Collection" master switch being OFF.
    ///
    /// When that switch is OFF, `SRSensorReader.requestAuthorization` returns an
    /// `SRError` with code `.promptDeclined` (NSError domain "SRErrorDomain", code 4) and
    /// the sensors stay `.notDetermined`. Crucially, the *same* `promptDeclined` error is
    /// returned when the user simply taps Cancel on a single sensor's prompt while
    /// collection is actually ON. We disambiguate the two by the elapsed time of the call:
    /// the master-off auto-decline returns far faster (< 0.8s) than a human can read and
    /// cancel a prompt. A slow promptDeclined (a real user cancel) is treated as a non-fatal
    /// decline and we continue to the next sensor.
    ///
    /// FUAM-3945 round 8: one fast decline is NOT enough to blame the master switch — a sensor the
    /// host is not entitled to auto-declines identically. The loop therefore always runs to the
    /// end, collecting both the FAST declines (< 0.8s) and the PROMPTLESS declines (< 3s, no
    /// drawn-prompt evidence — round 4), and the post-loop `setupOutcome` decides. (FUAM-3432)
    func requestPermissionsDetectingCollectionDisabled() -> Single<SensorKitSetupOutcome> {
        let toAsk = orderedNotDeterminedSensors()
        guard !toAsk.isEmpty else { return .just(.completed) }

        return Single.create { observer in
            if #available(iOS 17.4, *) {
                Task { @MainActor in
                    var fastDeclined: Set<SRSensor> = []
                    var promptlessDeclined: Set<SRSensor> = []
                    for sensor in toAsk {
                        let start = Date()
                        do {
                            try await SRSensorReader.requestAuthorization(sensors: [sensor])
                        } catch {
                            let elapsed = Date().timeIntervalSince(start)
                            #if DEBUG
                            print("SensorKitManager – requestAuthorization failed for \(sensor.rawValue): \(error)")
                            #endif
                            if Self.isFastAutoDecline(error: error, elapsed: elapsed) {
                                fastDeclined.insert(sensor)
                            }
                            if Self.isPromptlessDecline(error: error, elapsed: elapsed) {
                                promptlessDeclined.insert(sensor)
                            }
                            // Slow promptDeclined (real user cancel) or any other error:
                            // non-fatal, continue with the next sensor.
                        }
                    }
                    observer(.success(self.finishDetectingRound(asked: toAsk,
                                                                fastDeclined: fastDeclined,
                                                                promptlessDeclined: promptlessDeclined)))
                }
            } else {
                self.requestAuthorizationDetectingCollectionDisabled(sensors: toAsk) { fastDeclined, promptlessDeclined in
                    DispatchQueue.main.async {
                        observer(.success(self.finishDetectingRound(asked: toAsk,
                                                                    fastDeclined: fastDeclined,
                                                                    promptlessDeclined: promptlessDeclined)))
                    }
                }
            }
            return Disposables.create()
        }
    }

    /// Post-loop verdict + refusal-ledger update for one detect-capable request round (D6/D7).
    /// Call on the main thread once every asked sensor's request has returned.
    private func finishDetectingRound(asked: [SRSensor],
                                      fastDeclined: Set<SRSensor>,
                                      promptlessDeclined: Set<SRSensor>) -> SensorKitSetupOutcome {
        let anyAuthorized = self.hasAnyAuthorized()
        let outcome = Self.setupOutcome(fastDeclineCount: fastDeclined.count,
                                        promptlessDeclineCount: promptlessDeclined.count,
                                        askedCount: asked.count,
                                        anyAuthorizedAfterLoop: anyAuthorized,
                                        hasEntitlementDeclaration: SensorKitEntitlement.hostDeclaredValues() != nil)
        let stillNotDetermined = Set(asked.filter {
            SRSensorReader(sensor: $0).authorizationStatus == .notDetermined
        })
        let refused = Self.refusals(fastDeclined: fastDeclined,
                                    stillNotDetermined: stillNotDetermined,
                                    anyAuthorizedAfterLoop: anyAuthorized)
        // F5: this round's refusals are EVIDENCE; the store promotes a sensor to refused only
        // on its second sighting, and only the promotions are reported.
        let promoted = self.refusalStore.registerRefusalCandidates(refused)
        for sensor in promoted.sorted(by: { $0.rawValue < $1.rawValue }) {
            self.analyticsService.track(event: .sensorRefused(sensor: sensor.shortSubsource))
        }
        return outcome
    }

    /// Returns true if at least one of the configured, NON-REFUSED sensors is still
    /// undetermined — i.e. a request round could still change something (D6 layer 3: a sensor
    /// iOS refuses to prompt for stays `.notDetermined` forever and must not keep this true).
    func getIsAuthorizationStatusUndetermined() -> Single<Bool> {
        return .just(self.hasRequestableUndeterminedSensors())
    }

    // MARK: - Public control

    /// Triggers a manual sync (useful after permissions are granted or app returns foreground).
    func triggerSync(reason: String = "manual") {
        self.sensorSampleUploadManager.triggerSync(reason: "manual")
    }

    /// Ask SensorKit to start recording for all configured sensors.
    /// Safe to call multiple times; the framework ignores duplicates.
    func ensureRecordingStarted() {
        // Gate: if study/user clearance is off (e.g., no user), do nothing
        guard self.clearanceDelegate?.sensorManagerCanRun ?? false else { return }

        for sensor in self.readSensors {
            // Reuse or create the reader for this sensor. The delegate is what makes a failed
            // start visible: `startRecording()` reports asynchronously through
            // `sensorReader(_:startRecordingFailedWithError:)` and returns nothing, so a reader
            // with no delegate cannot tell success from failure (FUAM-3945 round 7, F3).
            let reader: SRSensorReader = {
                if let reader = recordingReaders[sensor] { return reader }
                let reader = SRSensorReader(sensor: sensor)
                reader.delegate = self
                recordingReaders[sensor] = reader
                return reader
            }()

            // Start recording this sensor
            reader.startRecording()  // instance method, no params
            #if DEBUG
            print("SensorKitManager - startRecording(\(sensor.rawValue))")
            #endif
        }
    }

    /// Requests authorization for each sensor one at a time using the completion-based API.
    /// Used on iOS 16.4–17.3 where the async API is unavailable.
    private func requestAuthorizationSequentially(sensors: [SRSensor],
                                                  completion: @escaping (_ firstError: Error?) -> Void) {
        var remaining = sensors
        var firstError: Error?

        func next() {
            guard let sensor = remaining.first else {
                completion(firstError)
                return
            }
            remaining.removeFirst()
            SRSensorReader.requestAuthorization(sensors: [sensor]) { error in
                if let error, firstError == nil {
                    firstError = error
                    #if DEBUG
                    print("SensorKitManager – requestAuthorization failed for \(sensor.rawValue): \(error)")
                    #endif
                }
                next()
            }
        }
        next()
    }

    /// Requests authorization for each sensor one at a time using the completion-based API,
    /// collecting the fast auto-declines. Used on iOS 16.4–17.3 where the async API is
    /// unavailable. Like the async path, the loop always runs to the end; the VERDICT is the
    /// caller's (`finishDetectingRound`), decided post-loop from the strongest evidence
    /// (FUAM-3945 round 9, D7).
    private func requestAuthorizationDetectingCollectionDisabled(
        sensors: [SRSensor],
        completion: @escaping (_ fastDeclined: Set<SRSensor>, _ promptlessDeclined: Set<SRSensor>) -> Void) {
        var remaining = sensors
        var fastDeclined: Set<SRSensor> = []
        var promptlessDeclined: Set<SRSensor> = []

        func next() {
            guard let sensor = remaining.first else {
                completion(fastDeclined, promptlessDeclined)
                return
            }
            remaining.removeFirst()
            let start = Date()
            SRSensorReader.requestAuthorization(sensors: [sensor]) { error in
                if let error {
                    let elapsed = Date().timeIntervalSince(start)
                    #if DEBUG
                    print("SensorKitManager – requestAuthorization failed for \(sensor.rawValue): \(error)")
                    #endif
                    if Self.isFastAutoDecline(error: error, elapsed: elapsed) {
                        // A slow promptDeclined is a real user cancel: not counted.
                        fastDeclined.insert(sensor)
                    }
                    if Self.isPromptlessDecline(error: error, elapsed: elapsed) {
                        promptlessDeclined.insert(sensor)
                    }
                }
                next()
            }
        }
        next()
    }

    /// Detects the `promptDeclined` SensorKit error returned when the system-wide
    /// "Sensor & Usage Data Collection" switch is OFF. Prefers the typed `SRError.code`,
    /// with an NSError domain/code fallback for safety. (FUAM-3432)
    private static func isPromptDeclined(_ error: Error) -> Bool {
        if (error as? SRError)?.code == .promptDeclined {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == "SRErrorDomain" && nsError.code == 4
    }

    /// Optional: stop recording for all sensors (e.g., on logout).
    func stopRecordingAll() {
        for (sensor, reader) in recordingReaders {
            reader.stopRecording()   // instance method
            #if DEBUG
            print("SensorKitManager - stopRecording(\(sensor.rawValue))")
            #endif
        }
    }
}

// MARK: - InitializableService (same pattern as HealthManager)

// MARK: - SRSensorReaderDelegate (recording only)

/// The manager is the delegate of the RECORDING readers only; every FETCH reader belongs to its
/// mapper, which is its own delegate. The single callback implemented here is the one that used
/// to be dropped on the floor: a `startRecording()` that never starts (missing entitlement,
/// system-wide collection off, an OS-side failure) looked exactly like a healthy sensor that
/// simply had no data, and the pipeline reported nothing for months. Retry behaviour is
/// unchanged — `didBecomeActive` already calls `ensureRecordingStarted()` again; this is
/// visibility only (FUAM-3945 round 7, F3).
extension SensorKitManager: SRSensorReaderDelegate {

    func sensorReader(_ reader: SRSensorReader, startRecordingFailedWithError error: Error) {
        let sensor = reader.sensor
        #if DEBUG
        print("SensorKitManager - startRecording failed for \(sensor.rawValue): \(error)")
        #endif
        // Once per sensor per launch: the retry loop would otherwise emit on every foreground.
        guard self.claimRecordingFailureReport(for: sensor) else { return }
        let nsError = error as NSError
        self.analyticsService.track(event: .sensorRecordingStartFailed(sensor: sensor.shortSubsource,
                                                                       error: "\(nsError.domain)/\(nsError.code)"))
    }
}

extension SensorKitManager: InitializableService {
    func initialize() -> Single<()> {
        self.isInitialized = true
        // Start the upload logic (reachability listeners + initial sync).
        self.ensureRecordingStarted()
        self.sensorSampleUploadManager.startUploadLogic()
        self.addApplicationDidBecomeActiveObserver()

        return .just(())
    }
}

extension Constants {
    struct SensorKit {
        /// Central list of sensors we ask permission for.
        /// Edit this set (or sovrascrivilo da remoto) per cambiare il comportamento.
        static var RequestedSensors: Set<SRSensor> = defaultRequestedSensors()

        // MARK: - Defaults
        /// The sensors permission is requested for. `Services` intersects this with the sensors
        /// that actually have a mapper, so a sensor listed here without a mapper is never asked
        /// for; keeping the two lists in step is what makes the enabled set readable in one place.
        /// FUAM-3945 round 7: `.accelerometer` and `.rotationRate` are deliberately absent (raw
        /// high-rate streams, see the mapper registry in `Services.swift`); pedometer and the two
        /// ambient sensors are requested — each authorization is asked for individually, so a
        /// sensor the host is not entitled to fails on its own and does not block the others.
        private static func defaultRequestedSensors() -> Set<SRSensor> {
            // Add here the sensors used by your study
            return [.pedometerData,
                    .ambientLightSensor,
                    .ambientPressure,
                    .visits,
                    .phoneUsageReport,
                    .deviceUsageReport,
                    .messagesUsageReport,
                    .keyboardMetrics]
        }

        // MARK: - Optional: server-driven override
        /// Map server strings -> SRSensor to drive this list from remote config.
        /// FUAM-3945 round 9 (F6): delegates to `SensorKitEntitlement.sensor(forEntitlementValue:)`
        /// — ONE mapping table for both the remote-config vocabulary and the entitlement ceiling,
        /// so the two can never drift apart again (the old copies already disagreed on
        /// `electrocardiogram` and `keyboard_events`).
        @available(iOS 17.4, *)
        static func makeSensors(from ids: [String]) -> Set<SRSensor> {
            return Set(ids.compactMap { SensorKitEntitlement.sensor(forEntitlementValue: $0) })
        }
    }
}

extension SensorKitManager {
    /// Start/Stop recording depending on current clearance (logged-in + consent).
    func refreshRecordingBasedOnClearance() {
        if self.clearanceDelegate?.sensorManagerCanRun ?? false {
            // Consent present → ensure recording is running
            self.ensureRecordingStarted()
        } else {
            // No consent/user → stop and purge local queues
            self.stopRecordingAll()
            self.triggerSync(reason: "no_clearance")
        }
    }
    
    func addApplicationDidBecomeActiveObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    @objc private func applicationDidBecomeActive() {
        // Gate: do nothing if study/user clearance is off (e.g., no user or consent off)
        guard self.clearanceDelegate?.sensorManagerCanRun ?? false else { return }
        
        // Safe & idempotent: SensorKit ignores duplicate starts
        self.ensureRecordingStarted()

        // FUAM-3945: a paired Watch appears in `fetchDevices()` only once it has synced data for
        // the sensor, so re-enumerate on every foreground before the cycle plans its windows.
        self.sensorSampleUploadManager.refreshDeviceCache()

        // Kick the pipeline. UploadManager already throttles internally.
        self.sensorSampleUploadManager.triggerSync(reason: "didBecomeActive")
    }
}

extension SensorKitManager {
    /// The full set of sensors this manager is configured to collect.
    /// Exposed so callers (e.g. the Permissions screen) can describe what the SDK
    /// cares about when the SensorKit settings alert is shown without any denied sensors.
    var configuredSensors: Set<SRSensor> {
        return Set(self.readSensors)
    }

    /// Returns true if at least one configured sensor is currently `.authorized`.
    /// Synchronous and cheap. The Permissions row uses it for BOTH its trailing label
    /// ("Manage" once anything is authorized, "Setup" otherwise) and its tap action
    /// (FUAM-3945 round 8): "no sensor is still undetermined" was the wrong basis, because a
    /// sensor iOS will never prompt for stays undetermined forever and wedged the row on "Setup"
    /// after the participant had granted everything.
    func hasAnyAuthorized() -> Bool {
        return self.readSensors.contains { SRSensorReader(sensor: $0).authorizationStatus == .authorized }
    }

    /// Return which sensors are still undetermined or denied.
    /// Call on main thread.
    func authorizationGaps() -> (undetermined: Set<SRSensor>, denied: Set<SRSensor>) {
        var undetermined = Set<SRSensor>()
        var denied = Set<SRSensor>()
        for s in self.readSensors {
            let status = SRSensorReader(sensor: s).authorizationStatus
            switch status {
            case .notDetermined: undetermined.insert(s)
            case .denied:        denied.insert(s)
            default: break
            }
        }
        return (undetermined, denied)
    }

    /// Ask only for sensors that are .notDetermined. No-op if none.
    /// Requests each sensor individually so one unapproved sensor does not crash the whole batch.
    /// Prompts appear in the order defined by `canonicalRequestOrder`.
    func requestPermissionsIfNeeded() -> Single<()> {
        let toAsk = orderedNotDeterminedSensors()
        guard !toAsk.isEmpty else { return .just(()) }

        return Single.create { observer in
            if #available(iOS 17.4, *) {
                Task { @MainActor in
                    var firstError: Error?
                    for sensor in toAsk {
                        do {
                            try await SRSensorReader.requestAuthorization(sensors: [sensor])
                        } catch {
                            if firstError == nil { firstError = error }
                            #if DEBUG
                            print("SensorKitManager – requestAuthorization failed for \(sensor.rawValue): \(error)")
                            #endif
                        }
                    }
                    if let firstError {
                        observer(.failure(SensorKitError.permissionRequestError(underlyingError: firstError)))
                    } else {
                        observer(.success(()))
                    }
                }
            } else {
                self.requestAuthorizationSequentially(sensors: toAsk) { firstError in
                    DispatchQueue.main.async {
                        if let firstError {
                            observer(.failure(SensorKitError.permissionRequestError(underlyingError: firstError)))
                        } else {
                            observer(.success(()))
                        }
                    }
                }
            }
            return Disposables.create()
        }
    }

    /// Hard stop + purge locale quando l’utente non c’è / logout
    func handleUserLoggedOut() {
        self.stopRecordingAll()
        self.triggerSync(reason: "logout")
    }
}

// MARK: - Entitlement ceiling (FUAM-3945 round 8, redesigned round 9 per D6)

/// Turns the host's SensorKit entitlement into the ceiling of the sensor set the SDK asks
/// permission for.
///
/// Why this exists: iOS never prompts for a sensor the app is not entitled to. The call returns
/// without showing anything and the sensor stays `.notDetermined` FOREVER. Two user-visible bugs
/// followed on Our Transitions (whose entitlement covers neither ambient light nor ambient
/// pressure, both of which round 7 added to `Constants.SensorKit.RequestedSensors`): the
/// Permissions row stayed on "Setup" after a full grant, and the re-ask loop read the instant
/// auto-decline of those two sensors as "system-wide collection is off".
///
/// **How the entitlement is learnt (D6, three layers):**
/// 1. PRIMARY — `FYAMSensorKitEntitledSensors`, an Info.plist array of Apple entitlement strings
///    the host copies verbatim from its `.entitlements` file. Round 8 tried to read
///    `embedded.mobileprovision` at runtime instead; Apple strips that file from App Store
///    builds (entitlement review F1), so the read was inert on the only channel that matters.
/// 2. DEBUG cross-check — development builds DO carry the provisioning profile, so DEBUG is the
///    one channel where the declaration can be verified against it (`assertionFailure` on drift).
/// 3. Fallback — the empirical refusal ledger (`SensorRefusalStore`): a sensor iOS refused to
///    prompt for is learnt after one request round and excluded from later rounds and the UI.
///
/// It is a **ceiling, not a floor**: a sensor that is entitled but deliberately absent from
/// `RequestedSensors` (e.g. `motion-accelerometer`, disabled for data volume) stays out.
///
/// It **fails open** (R1/F2 fix): a missing key keeps today's behaviour, and a non-empty key
/// mapping to ZERO known sensors also fails open — "I read a list and understood none of it" is
/// mapping drift on OUR side, not a host entitled to nothing. Only an explicitly EMPTY array
/// means "entitled to nothing" and is honoured as such.
enum SensorKitEntitlement {

    /// The entitlement key iOS uses to gate `SRSensorReader` access.
    static let entitlementKey = "com.apple.developer.sensorkit.reader.allow"

    /// The host's Info.plist declaration: the entitlement values, copied verbatim (D6 layer 1).
    static let infoPlistKey = "FYAMSensorKitEntitledSensors"

    /// The outcome of reading the host declaration. Pure, so the fail-open semantics have a
    /// regression test (R1).
    enum PlistResolution: Equatable {
        /// No key: nothing declared — fail open (no ceiling).
        case failOpen
        /// A non-empty declaration in which NOTHING mapped: our mapping table has drifted from
        /// Apple's vocabulary. Fail open AND report (`sensor_entitlement_missing`).
        case unmappable(values: [String])
        /// A usable declaration (including the explicit empty array = entitled to nothing).
        /// `unmapped` carries any leftover values that did not map — reported, not fatal.
        case entitled(Set<SRSensor>, unmapped: [String])
    }

    /// Resolves the host's declared values. `nil` means the key is absent or not a string array.
    static func resolveEntitledSensors(fromPlist values: [String]?) -> PlistResolution {
        guard let values = values else { return .failOpen }
        guard !values.isEmpty else { return .entitled([], unmapped: []) }
        let mapped = self.sensors(fromEntitlementValues: values)
        guard !mapped.isEmpty else { return .unmappable(values: values) }
        let unmapped = values.filter { self.sensor(forEntitlementValue: $0) == nil }
        return .entitled(mapped, unmapped: unmapped)
    }

    /// The raw `FYAMSensorKitEntitledSensors` array, or `nil` when absent/malformed.
    static func hostDeclaredValues(bundle: Bundle = .main) -> [String]? {
        guard let array = bundle.object(forInfoDictionaryKey: self.infoPlistKey) as? [Any] else { return nil }
        return array.compactMap { $0 as? String }
    }

    #if DEBUG
    /// D6 layer 2: development builds carry `embedded.mobileprovision` (that is exactly why the
    /// round-8 runtime read passed device QA), so DEBUG is where the plist declaration gets its
    /// verification loop. No-op when there is no declaration or no profile (simulator).
    static func debugCrossCheckProvisioningProfile(declared: [String]?) {
        guard let declared = declared, let profileValues = self.entitlementValues() else { return }
        let declaredSensors = self.sensors(fromEntitlementValues: declared)
        let profileSensors = self.sensors(fromEntitlementValues: profileValues)
        if declaredSensors != profileSensors {
            assertionFailure("FYAMSensorKitEntitledSensors \(declared.sorted()) disagrees with the provisioning "
                             + "profile's \(self.entitlementKey) \(profileValues.sorted()). "
                             + "Copy the values verbatim from the host .entitlements file.")
        }
    }
    #endif

    // MARK: Pure logic (unit-testable)

    /// Maps one entitlement value string to its `SRSensor`.
    ///
    /// Matching is case-insensitive and separator-insensitive: `-`, `_` and no separator at all are
    /// all accepted (`ambient-light-sensor` == `AMBIENT_LIGHT_SENSOR` == `ambientlightsensor`), and
    /// each sensor accepts the aliases Apple's documentation and our own remote-config vocabulary
    /// have used. Unknown strings return `nil` and are ignored — a value we cannot map must never
    /// be guessed into the wrong sensor.
    ///
    /// Confirmed against the Our Transitions production entitlement: `device-usage`,
    /// `messages-usage`, `pedometer`, `visits`, `motion-accelerometer`, `keyboard-metrics`,
    /// `phone-usage`. The remaining spellings are the documented ones and carry less certainty —
    /// which is why the aliases are generous; a spelling guessed wrong only costs the previous
    /// behaviour for that one sensor (it drops out of the requested set instead of hanging on
    /// `.notDetermined`). Sensors with neither a mapper nor a place in `RequestedSensors`
    /// (on-wrist, ECG, PPG, wrist temperature, speech metrics, …) are deliberately not mapped:
    /// since this set is only ever a ceiling, mapping them would change nothing.
    static func sensor(forEntitlementValue value: String) -> SRSensor? {
        switch self.normalized(value) {
        case "deviceusage", "deviceusagereport": return .deviceUsageReport
        case "messagesusage", "messagesusagereport": return .messagesUsageReport
        case "phoneusage", "phoneusagereport": return .phoneUsageReport
        case "keyboardmetrics", "keyboardevents": return .keyboardMetrics
        case "pedometer", "pedometerdata": return .pedometerData
        case "visits": return .visits
        case "motionaccelerometer", "accelerometer": return .accelerometer
        case "motionrotationrate", "rotationrate": return .rotationRate
        case "ambientlightsensor", "ambientlight": return .ambientLightSensor
        case "ambientpressure": return .ambientPressure
        case "mediaevents":
            if #available(iOS 16.4, *) { return .mediaEvents }
            return nil
        case "electrocardiogram", "ecg":
            // Carried over from the remote-config vocabulary (F6: this table is now the ONE
            // string -> SRSensor mapping, read by the entitlement ceiling AND by
            // `Constants.SensorKit.makeSensors(from:)`).
            if #available(iOS 17.4, *) { return .electrocardiogram }
            return nil
        default: return nil
        }
    }

    /// Lowercased with every `-` and `_` removed, so all three spellings collapse onto one key.
    private static func normalized(_ value: String) -> String {
        return value.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    /// Maps a whole entitlement array, dropping the values that have no known sensor.
    static func sensors(fromEntitlementValues values: [String]) -> Set<SRSensor> {
        return Set(values.compactMap { self.sensor(forEntitlementValue: $0) })
    }

    /// The set the SDK will actually request: requested ∩ has-a-mapper ∩ entitled.
    /// - Parameter entitled: `nil` means the entitlement could not be read — fail open and apply
    ///   only the first two terms.
    static func effectiveSensors(requested: Set<SRSensor>,
                                 mapped: Set<SRSensor>,
                                 entitled: Set<SRSensor>?) -> Set<SRSensor> {
        let configured = requested.intersection(mapped)
        guard let entitled = entitled else { return configured }
        return configured.intersection(entitled)
    }

    // MARK: Provisioning-profile read (DEBUG cross-check only)

    /// The raw entitlement values from `embedded.mobileprovision`, or `nil` when unreadable.
    ///
    /// FUAM-3945 round 9: this is NO LONGER the production source — Apple strips
    /// `embedded.mobileprovision` from App Store builds (entitlement review F1: Google ships
    /// "no embedded profile ⇒ App Store build" as a production heuristic in GoogleUtilities), so
    /// in the store this always returned `nil` and the round-8 ceiling silently failed open. The
    /// production source is the host's `FYAMSensorKitEntitledSensors` Info.plist declaration;
    /// this read survives only as the DEBUG cross-check, the one channel where the file exists.
    ///
    /// iOS has no public API for "read my own entitlements": `SecTaskCopyValueForEntitlement` is
    /// declared for macOS only and does not compile against the iOS SDK. The Simulator has no
    /// embedded profile either, so unit tests never trip the cross-check.
    static func entitlementValues() -> [String]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return self.entitlementValues(fromProvisioningProfile: data)
    }

    /// Extracts the entitlement values from a raw `embedded.mobileprovision`. The file is a CMS
    /// signature blob wrapped around an XML plist payload, so the payload is sliced out by its
    /// `<plist …>…</plist>` tags rather than by decoding the signature (which would need a
    /// certificate chain we do not have and do not need — the profile is already trusted, it came
    /// out of our own bundle).
    ///
    /// `nil` for anything unreadable: no payload, no `Entitlements`, no SensorKit key, or a value
    /// that is not an array. An array whose elements are not all strings yields the strings it does
    /// contain, so one malformed entry cannot make the whole read fail open.
    static func entitlementValues(fromProvisioningProfile data: Data) -> [String]? {
        guard let start = data.range(of: Data("<plist".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else {
            return nil
        }
        let payload = Data(data[start.lowerBound..<end.upperBound])
        guard let plist = try? PropertyListSerialization.propertyList(from: payload,
                                                                     options: [],
                                                                     format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let array = entitlements[self.entitlementKey] as? [Any] else {
            return nil
        }
        return array.compactMap { $0 as? String }
    }

    /// The `dropped_sensors` value of `sensor_entitlement_missing`, capped at Firebase's 100-char
    /// string-parameter limit (F7: all eight subsources joined run to 137 chars, and the all-eight
    /// case is precisely the one where this event is the only signal that SensorKit died). Names
    /// are sorted, whole names only are kept, and `count` carries the true cardinality.
    static func droppedSensorsParameter(_ sensors: [String], limit: Int = 100) -> (list: String, count: Int) {
        let sorted = sensors.sorted()
        var list = ""
        for name in sorted {
            let candidate = list.isEmpty ? name : list + "," + name
            guard candidate.count <= limit else { break }
            list = candidate
        }
        if list.isEmpty, let first = sorted.first {
            // A single name longer than the whole limit still needs something readable.
            list = String(first.prefix(limit))
        }
        return (list, sorted.count)
    }
}

// MARK: - Empirical refusal ledger (FUAM-3945 round 9, D6 layer 3)

/// Persists the sensors iOS has empirically refused to prompt for (asked, fast-declined with no
/// prompt drawn, still `.notDetermined` after the round). The fallback entitlement signal for a
/// host that ships no `FYAMSensorKitEntitledSensors` declaration: it needs one request round to
/// learn, then keeps the Permissions row truthful and stops the re-ask loop from re-triggering
/// the auto-decline. Cleared whenever the app version changes, so a host that GAINS an
/// entitlement in an update starts clean and re-asks once.
final class SensorRefusalStore {

    static let sensorsKey = "sensorkit.refusedSensors"
    static let candidatesKey = "sensorkit.refusedSensors.candidates"
    static let versionKey = "sensorkit.refusedSensors.version"

    private let defaults: UserDefaults
    private let version: String

    /// `version` defaults to `CFBundleShortVersionString-CFBundleVersion`: any release the host
    /// ships invalidates the ledger.
    init(defaults: UserDefaults = .standard, version: String? = nil) {
        self.defaults = defaults
        self.version = version ?? Self.currentBundleVersion()
        self.invalidateOnVersionChange()
    }

    func refusedSensors() -> Set<SRSensor> {
        return self.sensors(forKey: Self.sensorsKey)
    }

    /// One sighting is EVIDENCE, not proof (review round 1, F5): a transient system condition —
    /// a Screen Time restriction flipped on, a momentary SensorKit XPC fast-fail — during an
    /// otherwise-successful round would permanently lock an entitled, grantable sensor out
    /// until the next app version. A sensor is promoted to REFUSED only when it fast-declines
    /// in a SECOND, separate round; the first sighting is remembered as a candidate. Returns
    /// the sensors newly promoted this round (for telemetry).
    @discardableResult
    func registerRefusalCandidates(_ sensors: Set<SRSensor>) -> Set<SRSensor> {
        guard !sensors.isEmpty else { return [] }
        let candidates = self.sensors(forKey: Self.candidatesKey)
        let alreadyRefused = self.refusedSensors()
        let promoted = sensors.intersection(candidates).subtracting(alreadyRefused)
        if !promoted.isEmpty {
            self.recordRefusals(promoted)
        }
        let newCandidates = candidates.union(sensors)
        self.defaults.set(newCandidates.map { $0.rawValue }.sorted(), forKey: Self.candidatesKey)
        self.defaults.set(self.version, forKey: Self.versionKey)
        return promoted
    }

    /// Direct write, no candidate round-trip. Kept for tests and for callers that already hold
    /// proof (none in production today — `registerRefusalCandidates` is the production path).
    func recordRefusals(_ sensors: Set<SRSensor>) {
        guard !sensors.isEmpty else { return }
        let merged = self.refusedSensors().union(sensors)
        self.defaults.set(merged.map { $0.rawValue }.sorted(), forKey: Self.sensorsKey)
        self.defaults.set(self.version, forKey: Self.versionKey)
    }

    private func sensors(forKey key: String) -> Set<SRSensor> {
        guard let raw = self.defaults.stringArray(forKey: key) else { return [] }
        return Set(raw.map { SRSensor(rawValue: $0) })
    }

    private func invalidateOnVersionChange() {
        guard self.defaults.string(forKey: Self.versionKey) != self.version else { return }
        self.defaults.removeObject(forKey: Self.sensorsKey)
        self.defaults.removeObject(forKey: Self.candidatesKey)
        self.defaults.set(self.version, forKey: Self.versionKey)
    }

    private static func currentBundleVersion() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return short + "-" + build
    }
}

extension SRSensor {
    /// Returns the backend `sensor_kit` subsource (e.g., "accelerometer", "rotation_rate").
    /// Derived from the last component of Apple's raw identifier, snake_cased, except where that
    /// component does not name the sensor (FUAM-4251): those are mapped explicitly to the names
    /// in the backend allow-list (`app/lib/client_push.rb`).
    var shortSubsource: String {
        switch self {
        case .pedometerData: return "pedometer_data"             // com.apple.SensorKit.pedometer.data
        case .ambientLightSensor: return "ambient_light_sensor"  // com.apple.SensorKit.als
        case .rotationRate: return "rotation_rate"               // com.apple.SensorKit.motion.gyroscope
        default: break
        }
        let last = self.rawValue.split(separator: ".").last.map(String.init) ?? self.rawValue
        // camelCase -> snake_case, then normalize dashes
        var snake = ""
        for ch in last {
            if ch.isUppercase { snake.append("_"); snake.append(ch.lowercased()) }
            else { snake.append(ch) }
        }
        return snake.replacingOccurrences(of: "-", with: "_").lowercased()
    }
}
