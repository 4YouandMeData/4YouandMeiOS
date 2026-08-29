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

    /// Returns the `.notDetermined` subset of `readSensors`, sorted by
    /// `canonicalRequestOrder` (sensors not in the canonical list keep their input order
    /// and go at the end).
    private func orderedNotDeterminedSensors() -> [SRSensor] {
        let undetermined = readSensors.filter { SRSensorReader(sensor: $0).authorizationStatus == .notDetermined }
        let undeterminedSet = Set(undetermined)
        let canonical = Self.canonicalRequestOrder.filter { undeterminedSet.contains($0) }
        let extras = undetermined.filter { !Self.canonicalRequestOrder.contains($0) }
        return canonical + extras
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

    /// The verdict of a whole request sequence (FUAM-3945 round 8).
    ///
    /// A single fast `promptDeclined` used to be treated as proof that the system-wide "Sensor &
    /// Usage Data Collection" switch is OFF. It is not: a sensor the host has no entitlement for
    /// auto-declines exactly as fast, with the same error, while the switch is perfectly ON — which
    /// is how a participant who had granted everything still got the "collection is off" alert.
    /// Only a sequence in which EVERY asked sensor fast-declined can be the master switch; a mixed
    /// outcome is a per-sensor condition and the normal missing-sensors path handles it. Nothing
    /// asked means nothing to conclude.
    static func setupOutcome(fastDeclineCount: Int, askedCount: Int) -> SensorKitSetupOutcome {
        guard askedCount > 0, fastDeclineCount == askedCount else { return .completed }
        return .collectionDisabledSystemWide
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
    /// end and `setupOutcome(fastDeclineCount:askedCount:)` reports
    /// `.collectionDisabledSystemWide` only when EVERY asked sensor fast-declined. (FUAM-3432)
    func requestPermissionsDetectingCollectionDisabled() -> Single<SensorKitSetupOutcome> {
        let toAsk = orderedNotDeterminedSensors()
        guard !toAsk.isEmpty else { return .just(.completed) }

        return Single.create { observer in
            if #available(iOS 17.4, *) {
                Task { @MainActor in
                    var fastDeclines = 0
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
                                fastDeclines += 1
                            }
                            // Slow promptDeclined (real user cancel) or any other error:
                            // non-fatal, continue with the next sensor.
                        }
                    }
                    observer(.success(Self.setupOutcome(fastDeclineCount: fastDeclines, askedCount: toAsk.count)))
                }
            } else {
                self.requestAuthorizationDetectingCollectionDisabled(sensors: toAsk) { outcome in
                    DispatchQueue.main.async {
                        observer(.success(outcome))
                    }
                }
            }
            return Disposables.create()
        }
    }

    /// Returns true if at least one of the configured sensors is still undetermined.
    func getIsAuthorizationStatusUndetermined() -> Single<Bool> {
        let anyUndetermined = readSensors.contains { SRSensorReader(sensor: $0).authorizationStatus == .notDetermined }
        return .just(anyUndetermined)
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
    /// counting the fast auto-declines that reveal the system-wide SensorKit collection switch is
    /// OFF. Used on iOS 16.4–17.3 where the async API is unavailable. Like the async path, the loop
    /// always runs to the end: only an ALL-fast-decline sequence blames the master switch
    /// (FUAM-3945 round 8).
    private func requestAuthorizationDetectingCollectionDisabled(sensors: [SRSensor],
                                                                 completion: @escaping (_ outcome: SensorKitSetupOutcome) -> Void) {
        var remaining = sensors
        var fastDeclines = 0

        func next() {
            guard let sensor = remaining.first else {
                completion(Self.setupOutcome(fastDeclineCount: fastDeclines, askedCount: sensors.count))
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
                        fastDeclines += 1
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
        /// Map server strings -> SRSensor to drive this list from remote config
        @available(iOS 17.4, *)
        static func makeSensors(from ids: [String]) -> Set<SRSensor> {
            var set: Set<SRSensor> = []
            for id in ids {
                switch id.lowercased() {
                case "accelerometer": set.insert(.accelerometer)
                case "ambient_light", "ambientlight": set.insert(.ambientLightSensor)
                case "ambient_pressure", "ambientpressure": set.insert(.ambientPressure)
                case "pedometer", "pedometer_data", "pedometerdata": set.insert(.pedometerData)
                case "rotation_rate", "rotationrate": set.insert(.rotationRate)
                case "device_usage", "deviceusage": set.insert(.deviceUsageReport)
                case "messages_usage", "messagesusage": set.insert(.messagesUsageReport)
                case "phone_usage", "phoneusage": set.insert(.phoneUsageReport)
                case "visits": set.insert(.visits)
                case "keyboard_events": set.insert(.keyboardMetrics)
                case "electrocardiogram" : set.insert(.electrocardiogram)
                // TODO: add others
                default: break
                }
            }
            return set
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

// MARK: - Entitlement ceiling (FUAM-3945 round 8)

/// Reads the host app's OWN `com.apple.developer.sensorkit.reader.allow` entitlement and turns it
/// into the ceiling of the sensor set the SDK asks permission for.
///
/// Why this exists: iOS never prompts for a sensor the app is not entitled to. The call returns
/// without showing anything and the sensor stays `.notDetermined` FOREVER. Two user-visible bugs
/// followed on Our Transitions (whose entitlement covers neither ambient light nor ambient
/// pressure, both of which round 7 added to `Constants.SensorKit.RequestedSensors`): the
/// Permissions row stayed on "Setup" after a full grant, and the re-ask loop read the instant
/// auto-decline of those two sensors as "system-wide collection is off".
///
/// The entitlement is the single source of truth — deliberately NOT a host Info.plist list, which
/// would be a second place to keep in step and would drift.
///
/// It is a **ceiling, not a floor**: a sensor that is entitled but deliberately absent from
/// `RequestedSensors` (e.g. `motion-accelerometer`, disabled for data volume) stays out.
///
/// It **fails open**: when the entitlement cannot be read at all (API failure, missing key, a value
/// that is not an array) we keep the previous behaviour rather than silently stopping all
/// collection. An entitlement that IS readable but EMPTY is a genuine "entitled to nothing" and is
/// honoured as such.
enum SensorKitEntitlement {

    /// The entitlement key iOS uses to gate `SRSensorReader` access.
    static let entitlementKey = "com.apple.developer.sensorkit.reader.allow"

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

    // MARK: Runtime read

    /// The raw entitlement values of THIS app, or `nil` when they cannot be read (→ fail open).
    ///
    /// iOS has no public API for "read my own entitlements": `SecTaskCopyValueForEntitlement` is
    /// declared for macOS only and does not compile against the iOS SDK, and reaching it by
    /// `dlsym` is not something we are willing to ship through App Review. What every iOS build
    /// does carry is `embedded.mobileprovision`, whose `Entitlements` dictionary is what the App
    /// ID was provisioned with — the same list Apple approves when it grants SensorKit access.
    ///
    /// Two consequences, both benign here:
    /// - the Simulator has no embedded profile, so this returns `nil` and we fail open;
    /// - the profile is what the App ID is ENTITLED to, which can in principle be wider than what
    ///   a given build was signed with. Reading wide only ever restores the previous behaviour for
    ///   the extra sensor (asked for, never prompted), never blocks an entitled one.
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

    /// The sensors this build is entitled to read, or `nil` when the entitlement is unreadable.
    static func entitledSensors() -> Set<SRSensor>? {
        guard let values = self.entitlementValues() else { return nil }
        return self.sensors(fromEntitlementValues: values)
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

extension SRSensor {
    /// Returns a compact, snake_case subsource (e.g., "accelerometer", "rotation_rate").
    var shortSubsource: String {
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
