//
//  SensorDeviceProvider.swift
//  Pods
//
//  FUAM-3945: SensorKit stores data for the iPhone AND for a paired Apple Watch. A fetch
//  request targets ONE device (`SRFetchRequest.device`, default = current device), so a Watch
//  stream only ever arrives if we enumerate the devices and fetch each of them.
//

import Foundation
import SensorKit

/// One SensorKit data source, identified by KIND rather than by instance.
///
/// `SRDevice` exposes no stable identifier, Apple is blinding `name`, and `productType` changes
/// the day the participant upgrades their Watch — so tracking device *instances* is impossible.
/// Everything downstream (cursor key, telemetry name, record tag) keys on `key` instead:
/// `"iphone"` for the device the app runs on, `"watch"` for a paired Apple Watch.
///
/// ponytail: two Watches paired to one iPhone share the ONE `"watch"` cursor, so in practice only
/// the FIRST one enumerated backfills (review L2). The chain walks devices sequentially and each
/// device replans from the shared cursor, which the first Watch has already advanced to the end of
/// the plan — so the second same-key device plans no windows at all and contributes nothing that
/// cycle. Accepted: multi-Watch pairing is rare, and two Watches worn by the same participant
/// largely record the same thing anyway. Give them distinct keys only if a study ever has to tell
/// two Watches apart — which also needs a stable per-instance identifier `SRDevice` does not
/// expose.
public struct SensorDevice {

    /// The device to put on the `SRFetchRequest`. `nil` means "the current device", which is
    /// also the only way specs can build a watch-shaped `SensorDevice`: `SRDevice` cannot be
    /// instantiated outside SensorKit.
    public let device: SRDevice?

    /// Storage / telemetry / record-tag key — see `key(productType:systemName:)`.
    public let key: String

    /// `"Watch7,2"` and friends. Empty below iOS 17, where `SRDevice.productType` does not exist.
    public let productType: String

    /// `SRDevice.systemVersion`, e.g. `"10.2"`.
    public let systemVersion: String

    public static let iphoneKey = "iphone"
    public static let watchKey = "watch"

    public init(device: SRDevice?, key: String, productType: String, systemVersion: String) {
        self.device = device
        self.key = key
        self.productType = productType
        self.systemVersion = systemVersion
    }

    /// A device as `fetchDevices()` enumerated it.
    init(enumerated device: SRDevice) {
        let productType = Self.productType(of: device)
        self.init(device: device,
                  key: Self.key(productType: productType, systemName: device.systemName),
                  productType: productType,
                  systemVersion: device.systemVersion)
    }

    /// The device the app runs on — the only one every sensor is guaranteed to have, and the
    /// one the pipeline used exclusively before FUAM-3945.
    public static var current: SensorDevice {
        let device = SRDevice.current
        return SensorDevice(device: nil,
                            key: Self.iphoneKey,
                            productType: Self.productType(of: device),
                            systemVersion: device.systemVersion)
    }

    /// The device to hand to `SRFetchRequest.device`.
    var fetchTarget: SRDevice {
        return self.device ?? SRDevice.current
    }

    /// SensorKit's own 24h embargo already covers the iPhone. A paired Watch syncs its store to
    /// the phone on an undocumented, opportunistic schedule (community reports: hours to days,
    /// often while charging), and a UTC day fetched before the Watch has synced it comes back
    /// empty — after which the cursor, which only ever moves forward, has skipped it for good.
    ///
    /// ponytail: fixed 48h. Upgrade to an adaptive empty-tail re-scan (re-fetching trailing empty
    /// days is idempotent thanks to the UTC-day grid) if the per-device
    /// `sensor_data_backfill_reach` telemetry shows longer sync lags in the field.
    static let watchSyncHoldback: TimeInterval = 48 * 60 * 60

    /// Lower bound on how stale a device's data must be before we plan a window for it. Zero for
    /// the current device: the caller takes `max(sensorkitEmbargo, syncHoldback)`, so the iPhone
    /// keeps exactly today's 24h embargo.
    var syncHoldback: TimeInterval {
        return self.key == Self.iphoneKey ? 0 : Self.watchSyncHoldback
    }

    /// The per-record device tag. Applied centrally by `SensorSampleUploadManager` rather than by
    /// each of the 11 mappers, so the tag, the cursor key and the telemetry name can never drift
    /// apart. Free-form JSONB on the backend — additive, no allow-list change.
    var recordTags: [String: Any] {
        var tags: [String: Any] = ["device_kind": self.key,
                                   "device_os_version": self.systemVersion]
        // Absent below iOS 17; `device.name` is deliberately never sent (PII-ish, and Apple is
        // blinding it anyway).
        if !self.productType.isEmpty {
            tags["device_product_type"] = self.productType
        }
        return tags
    }

    /// The `sensor` dimension of `sensor_data_backfill_reach`. The iPhone keeps the bare sensor
    /// name so the existing series stay continuous across this release — same rule as the cursor
    /// key — while every other kind is suffixed, which is what makes reach observable per
    /// sensor+device.
    func telemetryName(for sensor: SRSensor) -> String {
        return self.key == Self.iphoneKey ? sensor.shortSubsource : "\(sensor.shortSubsource).\(self.key)"
    }

    /// Pure kind mapping — unit-testable without a real `SRDevice`.
    ///
    /// `systemName` decides, NOT `productType`: `SRDevice.productType` is iOS 17+ while the
    /// deployment floor is 15.6, so on 15/16 it is simply unreadable. `systemName` has existed
    /// since iOS 14 and already says `"watchOS"` for a paired Watch. `productType` is kept as a
    /// second opinion for the day Apple blinds `systemName` too.
    static func key(productType: String, systemName: String) -> String {
        let system = systemName.lowercased()
        let product = productType.lowercased()
        if system.contains("watch") || product.hasPrefix("watch") { return Self.watchKey }
        if system.contains("ios") || product.hasPrefix("iphone") { return Self.iphoneKey }
        // Defensive: an unknown platform still gets a stable, non-colliding, suffix-safe key
        // (it becomes part of a UserDefaults key), never an empty string.
        let sanitized = system.filter { $0.isLetter || $0.isNumber }
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    private static func productType(of device: SRDevice) -> String {
        if #available(iOS 17.0, *) {
            return device.productType
        }
        return ""
    }
}

/// Enumerates the devices that hold data for a sensor. The one seam FUAM-3945 adds, so the
/// per-device chain can be driven from unit tests.
protocol SensorDeviceProvider: AnyObject {

    /// The devices to fetch `sensor` from, current device FIRST. Never empty and never blocking:
    /// a sensor that has not been enumerated yet answers `[.current]` — exactly the pre-FUAM-3945
    /// behaviour — and kicks off a background enumeration that the next sync cycle picks up.
    func devices(for sensor: SRSensor) -> [SensorDevice]

    /// Forget what was enumerated, so the next `devices(for:)` asks SensorKit again. Called when
    /// the app comes to the foreground: a Watch appears in `fetchDevices()` only once it has
    /// synced data for that sensor, so the answer legitimately changes over time.
    func invalidate()
}

/// `SRSensorReader.fetchDevices()`-backed provider with an in-memory cache.
final class DefaultSensorDeviceProvider: SensorDeviceProvider {

    /// Sensors that are never enumerated: high-rate streams whose Watch twin would multiply an
    /// already-problematic volume (the accelerometer was disabled for exactly that reason, and a
    /// wrist-worn one is worse than a pocketed one). Both are disabled today, so this costs
    /// nothing now — it exists so that "re-enable the accelerometer" and "also fetch it from the
    /// Watch" stay two separate, deliberate decisions.
    static let enumerationDenylist: Set<SRSensor> = [.accelerometer, .rotationRate]

    /// Delegate callbacks are not guaranteed to fire. The timeout only releases the throwaway
    /// reader — nothing waits on it, since `devices(for:)` answers from the cache immediately.
    private let timeout: TimeInterval

    private let lock = NSLock()
    private var cache: [SRSensor: [SensorDevice]] = [:]
    /// At most one enumeration in flight per sensor; also what retains the delegate object,
    /// which `SRSensorReader` holds only weakly.
    private var inFlight: [SRSensor: DeviceEnumeration] = [:]

    init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    func devices(for sensor: SRSensor) -> [SensorDevice] {
        guard !Self.enumerationDenylist.contains(sensor) else { return [.current] }
        if let cached = self.locked({ self.cache[sensor] }) { return cached }
        self.refresh(sensor)
        return [.current]
    }

    func invalidate() {
        self.locked { self.cache.removeAll() }
    }

    private func refresh(_ sensor: SRSensor) {
        let enumeration: DeviceEnumeration? = self.locked {
            guard self.inFlight[sensor] == nil else { return nil }
            let enumeration = DeviceEnumeration(sensor: sensor)
            self.inFlight[sensor] = enumeration
            return enumeration
        }
        enumeration?.start(timeout: self.timeout) { [weak self] devices in
            guard let self else { return }
            self.locked {
                // A failed / timed-out enumeration caches NOTHING, so the next cycle retries
                // instead of freezing the sensor on `[.current]` until the next foreground.
                if let devices { self.cache[sensor] = Self.ordered(devices) }
                self.inFlight[sensor] = nil
            }
        }
    }

    /// Current device first, then the others by key. Deterministic order keeps the sequential
    /// device chain reproducible, and the union with `.current` means a flaky enumeration can
    /// never make the pipeline fetch LESS than it did before FUAM-3945.
    static func ordered(_ devices: [SensorDevice]) -> [SensorDevice] {
        let others = devices
            .filter { $0.key != SensorDevice.iphoneKey }
            .sorted { $0.key < $1.key }
        return [.current] + others
    }

    private func locked<T>(_ body: () -> T) -> T {
        self.lock.lock()
        defer { self.lock.unlock() }
        return body()
    }
}

/// One `fetchDevices()` round trip. `SRSensorReader` keeps its delegate weakly and is not
/// guaranteed to call back at all, so the enumeration is retained by the provider for the
/// duration and released either by the callback or by the timeout — a stuck enumeration costs one
/// reader per sensor, not an unbounded leak.
private final class DeviceEnumeration: NSObject, SRSensorReaderDelegate {

    private let reader: SRSensorReader
    private let lock = NSLock()
    private var completion: (([SensorDevice]?) -> Void)?

    init(sensor: SRSensor) {
        self.reader = SRSensorReader(sensor: sensor)
        super.init()
    }

    func start(timeout: TimeInterval, completion: @escaping ([SensorDevice]?) -> Void) {
        self.lock.lock()
        self.completion = completion
        self.lock.unlock()

        self.reader.delegate = self
        self.reader.fetchDevices()

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [weak self] in
            #if DEBUG
            print("DefaultSensorDeviceProvider - fetchDevices timed out")
            #endif
            self?.finish(nil)
        }
    }

    func sensorReader(_ reader: SRSensorReader, didFetch devices: [SRDevice]) {
        self.finish(devices.map { SensorDevice(enumerated: $0) })
    }

    func sensorReader(_ reader: SRSensorReader, fetchDevicesDidFailWithError error: Error) {
        #if DEBUG
        print("DefaultSensorDeviceProvider - fetchDevices failed: \(error)")
        #endif
        self.finish(nil)
    }

    /// Fires the completion at most once: the delegate and the timeout race by design.
    private func finish(_ devices: [SensorDevice]?) {
        self.lock.lock()
        let completion = self.completion
        self.completion = nil
        self.lock.unlock()
        completion?(devices)
    }
}
