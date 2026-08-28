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

        describe("SensorKitManager.setupOutcome(fastDeclineCount:askedCount:)") {

            it("reports the system-wide switch OFF only when EVERY asked sensor fast-declined") {
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 4, askedCount: 4)) == .collectionDisabledSystemWide
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 1, askedCount: 1)) == .collectionDisabledSystemWide
            }

            it("stays quiet on a mixed outcome — that is a per-sensor condition, not the master switch") {
                // The production defect: 2 unentitled sensors auto-decline instantly while the
                // other 6 prompt normally. One fast decline used to be enough to claim the
                // system-wide switch was off.
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 2, askedCount: 8)) == .completed
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 7, askedCount: 8)) == .completed
            }

            it("stays quiet when nothing declined") {
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 0, askedCount: 3)) == .completed
            }

            it("never reports 'disabled' when there was nothing to ask") {
                expect(SensorKitManager.setupOutcome(fastDeclineCount: 0, askedCount: 0)) == .completed
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
