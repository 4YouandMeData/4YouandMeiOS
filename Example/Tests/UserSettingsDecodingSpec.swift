//
//  UserSettingsDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-2937 / FUAM-2929: verifies UserSettings decodes the menstrual fields
//  added for the inline onboarding (FUAM-2937) and Settings panel (FUAM-2936)
//  including the BE date-only format and nullability of both fields.
//

import Quick
import Nimble
@testable import ForYouAndMe

class UserSettingsDecodingSpec: QuickSpec {
    override class func spec() {
        describe("UserSettings.decode menstrual fields") {

            // The framework has its own JSONAPIMappable wrapper, but the
            // attributes are decoded as a plain Codable struct. We exercise
            // that path directly with a single-level JSON to keep the test
            // independent of the JSON:API decoder.
            func decode(_ attributes: String) -> UserSettings? {
                let json = """
                { "id": "20", "type": "user_setting", \(attributes) }
                """.data(using: .utf8)!
                return try? JSONDecoder().decode(UserSettings.self, from: json)
            }

            it("decodes had_period_3mo enum values yes/no/unsure") {
                let yes = decode("\"menstrual_had_period_3mo\": \"yes\", \"menstrual_last_period_date\": null")
                expect(yes?.menstrualHadPeriod3Mo).to(equal(.yes))

                let no = decode("\"menstrual_had_period_3mo\": \"no\", \"menstrual_last_period_date\": null")
                expect(no?.menstrualHadPeriod3Mo).to(equal(.no))

                let unsure = decode("\"menstrual_had_period_3mo\": \"unsure\", \"menstrual_last_period_date\": null")
                expect(unsure?.menstrualHadPeriod3Mo).to(equal(.unsure))
            }

            it("decodes nil values when fields are explicitly null") {
                let item = decode("\"menstrual_had_period_3mo\": null, \"menstrual_last_period_date\": null")
                expect(item).toNot(beNil())
                expect(item?.menstrualHadPeriod3Mo).to(beNil())
                expect(item?.menstrualLastPeriodDate).to(beNil())
            }

            it("decodes nil values when fields are absent (legacy responses)") {
                let item = decode("\"daily_survey_time_seconds_since_midnight\": null")
                expect(item).toNot(beNil())
                expect(item?.menstrualHadPeriod3Mo).to(beNil())
                expect(item?.menstrualLastPeriodDate).to(beNil())
            }

            it("decodes the date in BE YYYY-MM-DD format") {
                let item = decode(
                    "\"menstrual_had_period_3mo\": \"yes\", \"menstrual_last_period_date\": \"2026-05-04\""
                )
                expect(item?.menstrualLastPeriodDate).toNot(beNil())

                // Verify the parsed date corresponds to 2026-05-04 in UTC.
                let formatted = UserSettings.dateOnlyFormatter.string(from: item!.menstrualLastPeriodDate!)
                expect(formatted).to(equal("2026-05-04"))
            }

            it("does not crash when the date is malformed (returns nil instead)") {
                let item = decode(
                    "\"menstrual_had_period_3mo\": \"yes\", \"menstrual_last_period_date\": \"not-a-date\""
                )
                expect(item).toNot(beNil())
                expect(item?.menstrualLastPeriodDate).to(beNil())
            }

            it("preserves unrelated fields") {
                let item = decode(
                    "\"daily_survey_time_seconds_since_midnight\": 3600, \"notification_time\": 9, " +
                    "\"menstrual_had_period_3mo\": \"yes\", \"menstrual_last_period_date\": \"2026-05-04\""
                )
                expect(item?.secondsFromMidnight).to(equal(3600))
                expect(item?.notificationTime).to(equal(9))
                expect(item?.menstrualHadPeriod3Mo).to(equal(.yes))
            }
        }

        describe("UserSettings.dateOnlyFormatter") {
            it("uses gregorian/UTC-equivalent and yyyy-MM-dd format") {
                expect(UserSettings.dateOnlyFormatter.dateFormat).to(equal("yyyy-MM-dd"))
                // Apple normalises "UTC" to "GMT" on some systems — both are
                // zero-offset, so assert on the offset rather than the name.
                expect(UserSettings.dateOnlyFormatter.timeZone.secondsFromGMT()).to(equal(0))
            }
            it("round-trips a date through string and back to the same calendar day") {
                let input = "2026-05-04"
                let parsed = UserSettings.dateOnlyFormatter.date(from: input)
                expect(parsed).toNot(beNil())
                let serialized = UserSettings.dateOnlyFormatter.string(from: parsed!)
                expect(serialized).to(equal(input))
            }
        }

        describe("UserSettings.needsMenstrualOnboarding (FUAM-2937 gate)") {
            // Helper since UserSettings.init isn't public; exercise via decode.
            func settings(hadPeriod3Mo: String?) -> UserSettings? {
                let value = hadPeriod3Mo.map { "\"\($0)\"" } ?? "null"
                let json = """
                {
                    "id": "20",
                    "type": "user_setting",
                    "menstrual_had_period_3mo": \(value),
                    "menstrual_last_period_date": null
                }
                """.data(using: .utf8)!
                return try? JSONDecoder().decode(UserSettings.self, from: json)
            }

            it("triggers when the baseline has never been configured") {
                expect(settings(hadPeriod3Mo: nil)?.needsMenstrualOnboarding).to(beTrue())
            }
            it("triggers when the user previously answered 'no' (contradicts adding a menstrual diary)") {
                expect(settings(hadPeriod3Mo: "no")?.needsMenstrualOnboarding).to(beTrue())
            }
            it("does NOT trigger when the user answered 'yes'") {
                expect(settings(hadPeriod3Mo: "yes")?.needsMenstrualOnboarding).to(beFalse())
            }
            it("does NOT trigger when the user answered 'unsure'") {
                expect(settings(hadPeriod3Mo: "unsure")?.needsMenstrualOnboarding).to(beFalse())
            }
        }
    }
}
