//
//  SensorKitEntitlementSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3945 round 8: the host's SensorKit entitlement as the ceiling of the requested set,
//  and the two user-visible defects that requesting an unentitled sensor caused.
//
//  The defect these specs defend against: iOS never prompts for a sensor the app has no
//  `com.apple.developer.sensorkit.reader.allow` entitlement for. The request auto-declines
//  instantly with the SAME `promptDeclined` error the system-wide switch produces, and the sensor
//  stays `.notDetermined` forever. On Our Transitions (entitled to pedometer but to neither ambient
//  sensor) that wedged the Permissions row on "Setup" after a full grant and popped the
//  "Sensor data collection is off" alert on every tap.
//
//  Under test (all static, no SensorKit/Security runtime needed):
//  - SensorKitEntitlement.sensor(forEntitlementValue:) — entitlement string -> SRSensor, with
//    case and separator tolerance, and unknown strings ignored rather than guessed.
//  - SensorKitEntitlement.effectiveSensors(requested:mapped:entitled:) — the three-way
//    intersection: the entitlement is a CEILING (entitled-but-not-requested stays out), a
//    requested-but-unentitled sensor is dropped, an unreadable entitlement FAILS OPEN and an
//    empty one means "entitled to nothing".
//  - SensorKitManager.setupOutcome(fastDeclineCount:askedCount:) — only an ALL-fast-decline
//    sequence may be blamed on the system-wide switch.
//  - AppNavigator.displayName(for:) — the study string when seeded, the rawValue when not.
//

import Quick
import Nimble
import RxSwift
import SensorKit
@testable import ForYouAndMe

class SensorKitEntitlementSpec: QuickSpec {

    override class func spec() {

        describe("SensorKitEntitlement.sensor(forEntitlementValue:)") {

            it("maps every value present in the Our Transitions production entitlement") {
                // Verbatim from `com.apple.developer.sensorkit.reader.allow` on production.
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "device-usage")) == .deviceUsageReport
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "messages-usage")) == .messagesUsageReport
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "pedometer")) == .pedometerData
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "visits")) == .visits
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "motion-accelerometer")) == .accelerometer
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "keyboard-metrics")) == .keyboardMetrics
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "phone-usage")) == .phoneUsageReport
            }

            it("maps the two sensors the OurTransitions entitlement does NOT cover") {
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "ambient-light-sensor")) == .ambientLightSensor
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "ambient-pressure")) == .ambientPressure
            }

            it("is case insensitive") {
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "PEDOMETER")) == .pedometerData
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "Device-Usage")) == .deviceUsageReport
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "Ambient-Light-Sensor")) == .ambientLightSensor
            }

            it("tolerates dash, underscore and no separator alike") {
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "keyboard_metrics")) == .keyboardMetrics
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "keyboardmetrics")) == .keyboardMetrics
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "ambient_pressure")) == .ambientPressure
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "MOTION_ACCELEROMETER")) == .accelerometer
            }

            it("ignores unknown strings instead of guessing a sensor") {
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "on-wrist")).to(beNil())
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "")).to(beNil())
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "pedometer-ish")).to(beNil())
                expect(SensorKitEntitlement.sensor(forEntitlementValue: "com.apple.SensorKit.pedometerData")).to(beNil())
            }

            it("maps a whole entitlement array, dropping the values it cannot map") {
                let values = ["device-usage", "pedometer", "not-a-sensor", "visits"]
                expect(SensorKitEntitlement.sensors(fromEntitlementValues: values))
                    == Set<SRSensor>([.deviceUsageReport, .pedometerData, .visits])
            }

            it("maps an empty array to an empty set (entitled to nothing, not to everything)") {
                expect(SensorKitEntitlement.sensors(fromEntitlementValues: [])).to(beEmpty())
            }
        }

        describe("SensorKitEntitlement.effectiveSensors(requested:mapped:entitled:)") {

            // The real round-7 configuration: everything requested has a mapper.
            let requested: Set<SRSensor> = [.pedometerData,
                                            .ambientLightSensor,
                                            .ambientPressure,
                                            .visits,
                                            .phoneUsageReport,
                                            .deviceUsageReport,
                                            .messagesUsageReport,
                                            .keyboardMetrics]
            let mapped: Set<SRSensor> = requested
            // The Our Transitions production entitlement, mapped.
            let otEntitled = SensorKitEntitlement.sensors(fromEntitlementValues: ["device-usage",
                                                                                  "messages-usage",
                                                                                  "pedometer",
                                                                                  "visits",
                                                                                  "motion-accelerometer",
                                                                                  "keyboard-metrics",
                                                                                  "phone-usage"])

            it("drops a requested sensor the host is not entitled to") {
                let result = SensorKitEntitlement.effectiveSensors(requested: requested,
                                                                  mapped: mapped,
                                                                  entitled: otEntitled)
                expect(result).toNot(contain(SRSensor.ambientLightSensor))
                expect(result).toNot(contain(SRSensor.ambientPressure))
            }

            it("keeps a sensor that is both requested and entitled") {
                let result = SensorKitEntitlement.effectiveSensors(requested: requested,
                                                                  mapped: mapped,
                                                                  entitled: otEntitled)
                expect(result) == Set<SRSensor>([.pedometerData,
                                                 .visits,
                                                 .phoneUsageReport,
                                                 .deviceUsageReport,
                                                 .messagesUsageReport,
                                                 .keyboardMetrics])
            }

            it("is a ceiling, not a floor: an entitled sensor we deliberately do not request stays out") {
                // `motion-accelerometer` IS entitled on production, and `.accelerometer` is
                // deliberately absent from `RequestedSensors` (raw high-rate stream, kills the
                // pipeline). The entitlement must not put it back.
                expect(otEntitled).to(contain(SRSensor.accelerometer))
                let result = SensorKitEntitlement.effectiveSensors(requested: requested,
                                                                  mapped: mapped,
                                                                  entitled: otEntitled)
                expect(result).toNot(contain(SRSensor.accelerometer))
            }

            it("drops a requested sensor that has no mapper, entitlement or not") {
                let result = SensorKitEntitlement.effectiveSensors(requested: [.pedometerData, .visits],
                                                                  mapped: [.pedometerData],
                                                                  entitled: [.pedometerData, .visits])
                expect(result) == Set<SRSensor>([.pedometerData])
            }

            it("FAILS OPEN when the entitlement is unreadable: requested ∩ mapped, unchanged") {
                let result = SensorKitEntitlement.effectiveSensors(requested: requested,
                                                                  mapped: mapped,
                                                                  entitled: nil)
                expect(result) == requested
            }

            it("honours an empty entitlement as 'entitled to nothing'") {
                let result = SensorKitEntitlement.effectiveSensors(requested: requested,
                                                                  mapped: mapped,
                                                                  entitled: [])
                expect(result).to(beEmpty())
            }
        }

        describe("SensorKitEntitlement.entitlementValues(fromProvisioningProfile:)") {

            /// An `embedded.mobileprovision` is a CMS blob wrapping an XML plist; these fixtures
            /// reproduce that shape — binary noise on both sides of the payload.
            func profile(entitlementsBody: String) -> Data {
                var data = Data([0x30, 0x82, 0x0B, 0xAD, 0x00, 0xFF])
                data.append(Data("""
                <?xml version="1.0" encoding="UTF-8"?>
                <plist version="1.0"><dict>
                <key>AppIDName</key><string>OurTransitions</string>
                <key>Entitlements</key><dict>\(entitlementsBody)</dict>
                </dict></plist>
                """.utf8))
                data.append(Data([0x00, 0xDE, 0xAD, 0xBE, 0xEF]))
                return data
            }

            let sensorKey = "com.apple.developer.sensorkit.reader.allow"

            it("reads the SensorKit array out of the CMS-wrapped payload") {
                let body = "<key>\(sensorKey)</key><array><string>pedometer</string><string>visits</string></array>"
                expect(SensorKitEntitlement.entitlementValues(fromProvisioningProfile: profile(entitlementsBody: body)))
                    == ["pedometer", "visits"]
            }

            it("returns an EMPTY array (entitled to nothing), not nil, for an empty entitlement") {
                let body = "<key>\(sensorKey)</key><array/>"
                let result = SensorKitEntitlement.entitlementValues(fromProvisioningProfile: profile(entitlementsBody: body))
                expect(result).toNot(beNil())
                expect(result).to(beEmpty())
            }

            it("returns nil (unreadable → fail open) when the profile has no SensorKit entitlement") {
                let body = "<key>aps-environment</key><string>production</string>"
                expect(SensorKitEntitlement.entitlementValues(fromProvisioningProfile: profile(entitlementsBody: body)))
                    .to(beNil())
            }

            it("returns nil (unreadable → fail open) when the entitlement is not an array") {
                let body = "<key>\(sensorKey)</key><string>pedometer</string>"
                expect(SensorKitEntitlement.entitlementValues(fromProvisioningProfile: profile(entitlementsBody: body)))
                    .to(beNil())
            }

            it("returns nil (unreadable → fail open) when there is no plist payload at all") {
                expect(SensorKitEntitlement.entitlementValues(fromProvisioningProfile: Data([0x30, 0x82, 0x00, 0x01])))
                    .to(beNil())
            }

            it("keeps the readable strings when one array entry is malformed") {
                let body = "<key>\(sensorKey)</key><array><string>pedometer</string><integer>7</integer></array>"
                expect(SensorKitEntitlement.entitlementValues(fromProvisioningProfile: profile(entitlementsBody: body)))
                    == ["pedometer"]
            }
        }

        describe("SensorKitManager.setupOutcome(fastDeclineCount:askedCount:anyAuthorizedAfterLoop:)") {

            // FUAM-3945 round 9 (D7/R3): the verdict is decided AFTER the loop from the
            // strongest evidence — anything authorized proves the master switch is ON; with
            // nothing authorized, a majority of fast declines blames the switch, so one slow
            // XPC cold-start cannot suppress a genuine detection (review F4).

            it("blames the switch when nothing authorized and everything fast-declined") {
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 4,
                                                     askedCount: 4,
                                                     anyAuthorizedAfterLoop: false,
                                                     hasEntitlementDeclaration: true))
                    == .collectionDisabledSystemWide
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 1,
                                                     askedCount: 1,
                                                     anyAuthorizedAfterLoop: false,
                                                     hasEntitlementDeclaration: true))
                    == .collectionDisabledSystemWide
            }

            it("survives one slow cold-start: 7 of 8 fast with nothing authorized is still the switch") {
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 7,
                                                     askedCount: 8,
                                                     anyAuthorizedAfterLoop: false,
                                                     hasEntitlementDeclaration: true))
                    == .collectionDisabledSystemWide
            }

            it("never blames the switch while ANYTHING is authorized (the permission-cell scenario)") {
                // 2 unentitled sensors fast-decline while 6 are authorized: a per-sensor
                // condition, not the master switch — the device-confirmed false alert.
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 2,
                                                     askedCount: 2,
                                                     anyAuthorizedAfterLoop: true,
                                                     hasEntitlementDeclaration: true))
                    == .completed
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 8,
                                                     askedCount: 8,
                                                     anyAuthorizedAfterLoop: true,
                                                     hasEntitlementDeclaration: true))
                    == .completed
            }

            it("stays quiet below a majority of fast declines") {
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 2,
                                                     askedCount: 8,
                                                     anyAuthorizedAfterLoop: false,
                                                     hasEntitlementDeclaration: true))
                    == .completed
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 0,
                                                     askedCount: 3,
                                                     anyAuthorizedAfterLoop: false,
                                                     hasEntitlementDeclaration: true))
                    == .completed
            }

            it("never reports 'disabled' when there was nothing to ask") {
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 0,
                                                     askedCount: 0,
                                                     anyAuthorizedAfterLoop: false,
                                                     hasEntitlementDeclaration: true))
                    == .completed
            }

            context("a host with NO entitlement declaration (round 2, review F6)") {

                it("does not blame the switch when half the set fast-declines and the user denies the rest") {
                    // No-plist host entitled to 4 of 8: 4 unentitled auto-declines + 4 real
                    // prompts the user DENIED (slow). The switch is ON — a majority rule here
                    // false-alarmed on every Setup tap, forever, and blocked refusal learning.
                    expect(SensorKitManager.setupOutcome(fastDeclineCount: 4,
                                                         askedCount: 8,
                                                         anyAuthorizedAfterLoop: false,
                                                         hasEntitlementDeclaration: false))
                        == .completed
                }

                it("still detects a genuinely off switch: everything fast-declines unanimously") {
                    expect(SensorKitManager.setupOutcome(fastDeclineCount: 8,
                                                         askedCount: 8,
                                                         anyAuthorizedAfterLoop: false,
                                                         hasEntitlementDeclaration: false))
                        == .collectionDisabledSystemWide
                }
            }
        }

        describe("SensorKitManager.refusals (the empirical entitlement fallback, D6 layer 3)") {

            it("records a sensor that fast-declined and stayed undetermined after a completed round") {
                let refused = SensorKitManager.refusals(fastDeclined: [.ambientLightSensor, .ambientPressure],
                                                        stillNotDetermined: [.ambientLightSensor, .ambientPressure],
                                                        outcome: .completed)
                expect(refused) == Set<SRSensor>([.ambientLightSensor, .ambientPressure])
            }

            it("records NOTHING from a round blamed on the master switch (it must not poison the ledger)") {
                let refused = SensorKitManager.refusals(fastDeclined: [.visits, .pedometerData],
                                                        stillNotDetermined: [.visits, .pedometerData],
                                                        outcome: .collectionDisabledSystemWide)
                expect(refused).to(beEmpty())
            }

            it("never records a slow user cancel — iOS will re-prompt it (R2)") {
                // Cancelled slowly: not in fastDeclined, still undetermined → not refused.
                let refused = SensorKitManager.refusals(fastDeclined: [],
                                                        stillNotDetermined: [.visits],
                                                        outcome: .completed)
                expect(refused).to(beEmpty())
            }
        }

        describe("SensorRefusalStore") {

            let defaults = UserDefaults.standard

            func wipe() {
                defaults.removeObject(forKey: SensorRefusalStore.sensorsKey)
                defaults.removeObject(forKey: SensorRefusalStore.candidatesKey)
                defaults.removeObject(forKey: SensorRefusalStore.versionKey)
            }

            beforeEach { wipe() }
            afterEach { wipe() }

            it("persists refusals and merges new ones") {
                let store = SensorRefusalStore(version: "1.0-1")
                store.recordRefusals([.ambientLightSensor])
                store.recordRefusals([.ambientPressure])
                expect(store.refusedSensors()) == Set<SRSensor>([.ambientLightSensor, .ambientPressure])
            }

            it("does NOT refuse a sensor on its first sighting — one transient fast decline is not proof (F5)") {
                let store = SensorRefusalStore(version: "1.0-1")
                let promoted = store.registerRefusalCandidates([.ambientLightSensor])
                expect(promoted).to(beEmpty())
                expect(store.refusedSensors()).to(beEmpty())
            }

            it("promotes a sensor refused in a SECOND, separate round, and reports only the promotion") {
                let store = SensorRefusalStore(version: "1.0-1")
                store.registerRefusalCandidates([.ambientLightSensor, .ambientPressure])
                let promoted = store.registerRefusalCandidates([.ambientLightSensor])
                expect(promoted) == Set<SRSensor>([.ambientLightSensor])
                expect(store.refusedSensors()) == Set<SRSensor>([.ambientLightSensor])
                // The pressure sensor stays a candidate: one sighting so far.
                expect(store.refusedSensors()).toNot(contain(SRSensor.ambientPressure))
            }

            it("does not re-promote (and re-report) an already-refused sensor") {
                let store = SensorRefusalStore(version: "1.0-1")
                store.registerRefusalCandidates([.ambientLightSensor])
                store.registerRefusalCandidates([.ambientLightSensor])
                expect(store.registerRefusalCandidates([.ambientLightSensor])).to(beEmpty())
            }

            it("clears itself — candidates included — when the app version changes") {
                let store = SensorRefusalStore(version: "1.0-1")
                store.registerRefusalCandidates([.ambientLightSensor])
                store.registerRefusalCandidates([.ambientLightSensor])
                let updated = SensorRefusalStore(version: "1.1-2")
                expect(updated.refusedSensors()).to(beEmpty())
                // The candidate memory is gone too: the first sighting after an update starts over.
                expect(updated.registerRefusalCandidates([.ambientLightSensor])).to(beEmpty())
            }

            it("keeps the ledger across launches of the same version") {
                SensorRefusalStore(version: "1.0-1").recordRefusals([.ambientLightSensor])
                expect(SensorRefusalStore(version: "1.0-1").refusedSensors()) == Set<SRSensor>([.ambientLightSensor])
            }
        }

        describe("SensorKitPermissionRowState (D7: label and action are two different questions)") {

            it("partial grant: Manage label AND the request flow — the R2 regression guard") {
                // Granted sensor 1, cancelled prompt 2: the row must say Manage but the tap must
                // re-run the request flow, or prompts 2..8 are unreachable for ever.
                let state = SensorKitPermissionRowState.resolve(anyAuthorized: true, hasRequestableUndetermined: true)
                expect(state.showsManageLabel).to(beTrue())
                expect(state.action) == SensorKitPermissionRowState.Action.requestFlow
            }

            it("everything decided (or refused): Manage label, settings alert") {
                let state = SensorKitPermissionRowState.resolve(anyAuthorized: true, hasRequestableUndetermined: false)
                expect(state.action) == SensorKitPermissionRowState.Action.settingsAlert
            }

            it("fresh install: Setup label, request flow") {
                let state = SensorKitPermissionRowState.resolve(anyAuthorized: false, hasRequestableUndetermined: true)
                expect(state.showsManageLabel).to(beFalse())
                expect(state.action) == SensorKitPermissionRowState.Action.requestFlow
            }

            it("nothing granted and nothing promptable (all refused): Setup label, settings alert") {
                let state = SensorKitPermissionRowState.resolve(anyAuthorized: false, hasRequestableUndetermined: false)
                expect(state.showsManageLabel).to(beFalse())
                expect(state.action) == SensorKitPermissionRowState.Action.settingsAlert
            }
        }

        describe("SensorKitEntitlement.resolveEntitledSensors(fromPlist:) — the host declaration (D6 layer 1)") {

            it("fails open when the key is absent") {
                expect(SensorKitEntitlement.resolveEntitledSensors(fromPlist: nil))
                    == SensorKitEntitlement.PlistResolution.failOpen
            }

            it("honours an explicit empty array as 'entitled to nothing'") {
                expect(SensorKitEntitlement.resolveEntitledSensors(fromPlist: []))
                    == SensorKitEntitlement.PlistResolution.entitled([], unmapped: [])
            }

            it("FAILS OPEN — with the values reported — when a non-empty declaration maps to nothing (R1)") {
                // 'I read a list and understood none of it' is OUR mapping drift, not a host
                // entitled to nothing: silently disabling all collection here was the round-8
                // fail-closed regression.
                let values = ["some-future-sensor", "another-one"]
                expect(SensorKitEntitlement.resolveEntitledSensors(fromPlist: values))
                    == SensorKitEntitlement.PlistResolution.unmappable(values: values)
            }

            it("maps a usable declaration and carries the unmapped leftovers for telemetry") {
                let resolution = SensorKitEntitlement.resolveEntitledSensors(fromPlist: ["pedometer", "mystery-sensor"])
                expect(resolution)
                    == SensorKitEntitlement.PlistResolution.entitled([.pedometerData], unmapped: ["mystery-sensor"])
            }
        }

        describe("the single mapping table (F6: remote config and entitlement can no longer drift)") {

            it("resolves the remote-config vocabulary through the same table as the entitlements") {
                guard #available(iOS 17.4, *) else { return }
                let ids = ["ambient_light", "keyboard_events", "device_usage", "electrocardiogram", "visits"]
                let viaRemoteConfig = Constants.SensorKit.makeSensors(from: ids)
                let viaEntitlement = Set(ids.compactMap { SensorKitEntitlement.sensor(forEntitlementValue: $0) })
                expect(viaRemoteConfig) == viaEntitlement
                expect(viaRemoteConfig).to(contain(SRSensor.electrocardiogram))
                expect(viaRemoteConfig).to(contain(SRSensor.keyboardMetrics))
            }
        }

        describe("droppedSensorsParameter (F7: Firebase caps string parameters at 100 chars)") {

            it("keeps all eight subsources under the cap and reports the true count") {
                let all = [SRSensor.deviceUsageReport, .messagesUsageReport, .phoneUsageReport,
                           .ambientLightSensor, .ambientPressure, .keyboardMetrics,
                           .pedometerData, .visits].map { $0.shortSubsource }
                let parameter = SensorKitEntitlement.droppedSensorsParameter(all)
                expect(parameter.list.count).to(beLessThanOrEqualTo(100))
                expect(parameter.count) == 8
                // Whole names only: the capped list must still be parseable.
                for name in parameter.list.split(separator: ",") {
                    expect(all).to(contain(String(name)))
                }
            }

            it("leaves a short list untouched") {
                let parameter = SensorKitEntitlement.droppedSensorsParameter(["ambient_light_sensor", "ambient_pressure"])
                expect(parameter.list) == "ambient_light_sensor,ambient_pressure"
                expect(parameter.count) == 2
            }
        }

        describe("AppNavigator.displayName(for:)") {

            afterEach {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
            }

            it("returns the study string when the backend has seeded it") {
                StringsProvider.initialize(withFullStringMap: [:],
                                           requiredStringMap: [.permissionSensorKitNamePedometer: "Steps"])
                expect(AppNavigator.displayName(for: .pedometerData)) == "Steps"
            }

            it("falls back to the raw sensor value when the study string is absent") {
                StringsProvider.initialize(withFullStringMap: [:], requiredStringMap: [:])
                expect(AppNavigator.displayName(for: .pedometerData)) == SRSensor.pedometerData.rawValue
            }

            it("falls back to the raw sensor value when the study string is present but empty") {
                StringsProvider.initialize(withFullStringMap: [:],
                                           requiredStringMap: [.permissionSensorKitNamePedometer: ""])
                expect(AppNavigator.displayName(for: .pedometerData)) == SRSensor.pedometerData.rawValue
            }

            it("has a key for the other two round-7 sensors, so no raw value ever reaches a participant") {
                StringsProvider.initialize(withFullStringMap: [:],
                                           requiredStringMap: [.permissionSensorKitNameAmbientLight: "Ambient light",
                                                               .permissionSensorKitNameAmbientPressure: "Air pressure"])
                expect(AppNavigator.displayName(for: .ambientLightSensor)) == "Ambient light"
                expect(AppNavigator.displayName(for: .ambientPressure)) == "Air pressure"
            }
        }
    }
}

// MARK: - FUAM-3945 round 9: refused sensors leave the request order and the row aggregate

/// Manager-level composition of the refusal ledger (D6 layer 3): a refused sensor must stop
/// feeding `getIsAuthorizationStatusUndetermined` / `hasRequestableUndeterminedSensors`, or the
/// Permissions row would keep re-running a request flow that can never succeed.
class SensorRefusalExclusionSpec: QuickSpec {

    override class func spec() {

        let defaults = UserDefaults.standard

        func currentVersion() -> String {
            let info = Bundle.main.infoDictionary
            let short = info?["CFBundleShortVersionString"] as? String ?? "0"
            let build = info?["CFBundleVersion"] as? String ?? "0"
            return short + "-" + build
        }

        func makeManager() -> SensorKitManager {
            return SensorKitManager(withReadSensors: [.pedometerData],
                                    analyticsService: CapturingAnalyticsService(),
                                    storage: NullSensorStorage(),
                                    reachability: FakeEntitlementReachability(),
                                    mappers: [:])
        }

        beforeEach {
            defaults.removeObject(forKey: SensorRefusalStore.sensorsKey)
            defaults.removeObject(forKey: SensorRefusalStore.candidatesKey)
            defaults.removeObject(forKey: SensorRefusalStore.versionKey)
        }
        afterEach {
            defaults.removeObject(forKey: SensorRefusalStore.sensorsKey)
            defaults.removeObject(forKey: SensorRefusalStore.candidatesKey)
            defaults.removeObject(forKey: SensorRefusalStore.versionKey)
        }

        it("stops counting a refused sensor as requestable") {
            // Control first: on this simulator the sensor must read `.notDetermined`, or the
            // example cannot distinguish anything and bails out rather than asserting vacuously.
            guard makeManager().hasRequestableUndeterminedSensors() else { return }

            // Seed the ledger under the REAL bundle version (the store clears itself on any
            // version change, which is itself under test in SensorRefusalStore specs).
            SensorRefusalStore(version: currentVersion()).recordRefusals([.pedometerData])

            expect(makeManager().hasRequestableUndeterminedSensors()).to(beFalse())
        }
    }
}

private final class FakeEntitlementReachability: SensorSampleUploadManagerReachability {
    var isReachable: Bool = true
    var reachabilityChanged: Observable<Bool> { return .empty() }
}

/// Inert storage: this spec never runs the upload pipeline.
private final class NullSensorStorage: SensorSampleUploadManagerStorage, SensorSampleUploaderStorage {
    func lastCursor(for sensor: SRSensor, deviceKey: String) -> Date? { return nil }
    func setLastCursor(_ date: Date, for sensor: SRSensor, deviceKey: String) {}
    @discardableResult
    func enqueueBatch(_ batch: [[String: Any]], windowStart: Date, for sensor: SRSensor) -> Bool { return true }
    func dequeueNextBatch(for sensor: SRSensor) -> (records: [[String: Any]], windowStart: Date)? { return nil }
    func pendingBatchCount(for sensor: SRSensor) -> Int { return 0 }
    func ledger(for sensor: SRSensor, deviceKey: String) -> [String: SensorLedgerEntry] { return [:] }
    func setLedger(_ ledger: [String: SensorLedgerEntry], for sensor: SRSensor, deviceKey: String) {}
    func purgeLedger(for sensor: SRSensor) {}
    func lastRescanDay(for sensor: SRSensor, deviceKey: String) -> Date? { return nil }
    func setLastRescanDay(_ day: Date, for sensor: SRSensor, deviceKey: String) {}
    func deepestProductiveWindowStart(for sensor: SRSensor, deviceKey: String) -> Date? { return nil }
    func setDeepestProductiveWindowStart(_ date: Date, for sensor: SRSensor, deviceKey: String) {}
}
