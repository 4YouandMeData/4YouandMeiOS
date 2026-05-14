//
//  MenstrualUserSettingsTaskSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2937 / FUAM-2936: verifies DefaultService.sendMenstrualUserSettings
//  builds the PATCH body for /v1/user_setting matching the BE schema
//  (FUAM-2929: menstrual_had_period_3mo enum yes/no/unsure, nullable;
//  menstrual_last_period_date as YYYY-MM-DD, nullable).
//

import Quick
import Nimble
import Moya
@testable import ForYouAndMe

class MenstrualUserSettingsTaskSpec: QuickSpec {
    override class func spec() {
        describe("DefaultService.sendMenstrualUserSettings task body") {

            // 2026-04-20 at noon UTC — picked so the date-only formatter
            // serializes deterministically regardless of the device timezone.
            let isoFmt: ISO8601DateFormatter = {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                return f
            }()
            let knownDate = isoFmt.date(from: "2026-04-20T12:00:00Z")!

            it("emits both fields under user_setting wrapper when both are set") {
                let service = DefaultService.sendMenstrualUserSettings(hadPeriod3Mo: .yes,
                                                                       lastPeriodDate: knownDate)
                let params = unwrapRequestParameters(service.task)

                guard let userSetting = params?["user_setting"] as? [String: Any] else {
                    fail("Missing user_setting wrapper in body: \(String(describing: params))")
                    return
                }
                expect(userSetting["menstrual_had_period_3mo"] as? String).to(equal("yes"))
                expect(userSetting["menstrual_last_period_date"] as? String).to(equal("2026-04-20"))
            }

            it("encodes the enum as yes/no/unsure (BE contract)") {
                let cases: [(MenstrualHadPeriod3Mo, String)] = [
                    (.yes, "yes"),
                    (.no, "no"),
                    (.unsure, "unsure")
                ]
                for (value, expected) in cases {
                    let service = DefaultService.sendMenstrualUserSettings(hadPeriod3Mo: value,
                                                                           lastPeriodDate: nil)
                    let payload = (unwrapRequestParameters(service.task)?["user_setting"]) as? [String: Any]
                    expect(payload?["menstrual_had_period_3mo"] as? String).to(equal(expected))
                }
            }

            it("serializes the date as YYYY-MM-DD (date-only, no timestamp)") {
                let service = DefaultService.sendMenstrualUserSettings(hadPeriod3Mo: .yes,
                                                                       lastPeriodDate: knownDate)
                let payload = (unwrapRequestParameters(service.task)?["user_setting"]) as? [String: Any]
                let dateStr = payload?["menstrual_last_period_date"] as? String
                expect(dateStr).to(equal("2026-04-20"))
                // Must NOT include time information.
                expect(dateStr).toNot(contain("T"))
                expect(dateStr).toNot(contain(":"))
                expect(dateStr).toNot(contain("Z"))
            }

            it("explicitly sends NSNull for nil hadPeriod3Mo so BE can clear it") {
                let service = DefaultService.sendMenstrualUserSettings(hadPeriod3Mo: nil,
                                                                       lastPeriodDate: knownDate)
                let payload = (unwrapRequestParameters(service.task)?["user_setting"]) as? [String: Any]
                expect(payload?["menstrual_had_period_3mo"]).toNot(beNil())
                expect(payload?["menstrual_had_period_3mo"] is NSNull).to(beTrue())
            }

            it("explicitly sends NSNull for nil lastPeriodDate so BE can clear it") {
                let service = DefaultService.sendMenstrualUserSettings(hadPeriod3Mo: .no,
                                                                       lastPeriodDate: nil)
                let payload = (unwrapRequestParameters(service.task)?["user_setting"]) as? [String: Any]
                expect(payload?["menstrual_last_period_date"]).toNot(beNil())
                expect(payload?["menstrual_last_period_date"] is NSNull).to(beTrue())
            }

            it("does not clobber other UserSetting fields (no daily_survey_time / notification_time keys)") {
                // Hygiene: the dedicated case must not write to the unrelated
                // notification_time / daily_survey_time fields. Crashes reach
                // here as nil keys, so the assertion is "key absent".
                let service = DefaultService.sendMenstrualUserSettings(hadPeriod3Mo: .yes,
                                                                       lastPeriodDate: knownDate)
                let payload = (unwrapRequestParameters(service.task)?["user_setting"]) as? [String: Any]
                expect(payload?.keys).toNot(contain("notification_time"))
                expect(payload?.keys).toNot(contain("daily_survey_time_seconds_since_midnight"))
            }
        }
    }
}

// MARK: - Helpers

private func unwrapRequestParameters(_ task: Task) -> [String: Any]? {
    if case let .requestParameters(parameters, _) = task {
        return parameters
    }
    return nil
}
