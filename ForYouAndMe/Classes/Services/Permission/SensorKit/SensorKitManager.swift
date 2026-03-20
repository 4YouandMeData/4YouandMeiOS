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
final class SensorKitManager: SensorKitService {

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
    }

    // MARK: - SensorKitService

    /// Availability gate (entitlements + Info.plist already configured on your build).
    var serviceAvailable: Bool { true }

    /// Requests SensorKit authorization for all not-determined sensors in `readSensors`.
    /// Requests each sensor individually so one unapproved sensor does not crash the whole batch.
    func requestPermissions() -> Single<()> {
        // Build the set of sensors still undetermined
        let toAsk = readSensors.filter { SRSensorReader(sensor: $0).authorizationStatus == .notDetermined }
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
            // Reuse or create the reader for this sensor
            let reader: SRSensorReader = {
                if let reader = recordingReaders[sensor] { return reader }
                let reader = SRSensorReader(sensor: sensor)
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
        private static func defaultRequestedSensors() -> Set<SRSensor> {
            // Add here the sensors used by your study
            if #available(iOS 16.4, *) {
                return [.accelerometer,
                    .visits,
                    .phoneUsageReport,
                    .deviceUsageReport,
                    .messagesUsageReport,
                    .keyboardMetrics,
                    .mediaEvents]
            } else {
                // Fallback on earlier versions
                return [.accelerometer,
                        .visits,
                        .phoneUsageReport,
                        .deviceUsageReport,
                        .messagesUsageReport,
                        .keyboardMetrics]
            }
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
        
        // Kick the pipeline. UploadManager already throttles internally.
        self.sensorSampleUploadManager.triggerSync(reason: "didBecomeActive")
    }
}

extension SensorKitManager {
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
    func requestPermissionsIfNeeded() -> Single<()> {
        let toAsk = self.readSensors.filter { SRSensorReader(sensor: $0).authorizationStatus == .notDetermined }
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
