//
//  FeaturesConfigurationDecodingSpec.swift
//  ForYouAndMe_Tests
//
//  FUAM-3342: locks down the study-level "Features Configuration" gating.
//  Verifies the tolerant BE-payload parse (Mapper.extractFeaturesConfiguration),
//  the enabled/absent/false semantics of FeaturesConfiguration.isEnabled, and
//  that FeatureFlagProvider mirrors those semantics (default = disabled) so the
//  Settings menstrual-cycle panel stays hidden unless the study opts in.
//

import Quick
import Nimble
@testable import ForYouAndMe

class FeaturesConfigurationDecodingSpec: QuickSpec {
    override class func spec() {

        describe("Mapper.extractFeaturesConfiguration (BE features_configuration payload)") {

            // Mirrors the flat object the backend nests under "features_configuration"
            // (each entry is `{ enabled: Bool, order: Int? }`). We route through
            // JSONSerialization so the runtime types match the real network path
            // (NSNumber-backed booleans/ints), which is what the extractor sees.
            func parse(_ json: String) -> FeaturesConfiguration? {
                let object = try? JSONSerialization.jsonObject(with: Data(json.utf8))
                return try? Mapper.extractFeaturesConfiguration(object: object)
            }

            it("parses enabled true/false and optional order") {
                let config = parse("""
                {
                    "menstrual_period": { "enabled": true, "order": 3 },
                    "hot_flash": { "enabled": false, "order": 1 },
                    "reflections": { "enabled": true }
                }
                """)
                expect(config).toNot(beNil())
                expect(config?.isEnabled(.menstrualPeriod)).to(beTrue())
                expect(config?.order(.menstrualPeriod)).to(equal(3))
                expect(config?.isEnabled(.hotFlash)).to(beFalse())
                expect(config?.isEnabled(.reflections)).to(beTrue())
                // order absent -> nil
                expect(config?.order(.reflections)).to(beNil())
            }

            it("skips malformed entries but keeps well-formed ones (tolerant parse)") {
                let config = parse("""
                {
                    "menstrual_period": { "enabled": true },
                    "broken_no_enabled": { "order": 2 },
                    "broken_not_an_object": "nope"
                }
                """)
                expect(config).toNot(beNil())
                expect(config?.isEnabled(.menstrualPeriod)).to(beTrue())
                // Malformed keys are dropped, so they read as disabled.
                expect(config?.flags["broken_no_enabled"]).to(beNil())
                expect(config?.flags["broken_not_an_object"]).to(beNil())
            }

            it("keeps unknown/future feature keys verbatim in the raw map") {
                let config = parse("""
                { "some_future_feature": { "enabled": true, "order": 9 } }
                """)
                expect(config?.flags["some_future_feature"]?.enabled).to(beTrue())
                expect(config?.flags["some_future_feature"]?.order).to(equal(9))
            }

            it("throws when the value is not a JSON object") {
                expect { try Mapper.extractFeaturesConfiguration(object: "not-an-object") }.to(throwError())
            }
        }

        describe("FeaturesConfiguration.isEnabled default-disabled semantics") {

            it("is false when the menstrual_period key is absent") {
                let config = FeaturesConfiguration(flags: [:])
                expect(config.isEnabled(.menstrualPeriod)).to(beFalse())
            }

            it("is false when the key is present but enabled == false") {
                let config = FeaturesConfiguration(flags: [
                    "menstrual_period": FeatureFlag(enabled: false, order: nil)
                ])
                expect(config.isEnabled(.menstrualPeriod)).to(beFalse())
            }

            it("is true only when the key is present and enabled == true") {
                let config = FeaturesConfiguration(flags: [
                    "menstrual_period": FeatureFlag(enabled: true, order: nil)
                ])
                expect(config.isEnabled(.menstrualPeriod)).to(beTrue())
            }
        }

        describe("FeatureFlagProvider gate (drives the Settings menstrual panel)") {

            afterEach {
                // Restore the default (no configuration) so later specs stay isolated.
                FeatureFlagProvider.initialize(withFeaturesConfiguration: nil)
            }

            it("is disabled when no features configuration has been seeded") {
                FeatureFlagProvider.initialize(withFeaturesConfiguration: nil)
                expect(FeatureFlagProvider.isFeatureEnabled(.menstrualPeriod)).to(beFalse())
            }

            it("is disabled when the study explicitly turns the feature off") {
                FeatureFlagProvider.initialize(withFeaturesConfiguration: FeaturesConfiguration(flags: [
                    "menstrual_period": FeatureFlag(enabled: false, order: nil)
                ]))
                expect(FeatureFlagProvider.isFeatureEnabled(.menstrualPeriod)).to(beFalse())
            }

            it("is enabled when the study opts the feature in") {
                FeatureFlagProvider.initialize(withFeaturesConfiguration: FeaturesConfiguration(flags: [
                    "menstrual_period": FeatureFlag(enabled: true, order: nil)
                ]))
                expect(FeatureFlagProvider.isFeatureEnabled(.menstrualPeriod)).to(beTrue())
            }
        }
    }
}
